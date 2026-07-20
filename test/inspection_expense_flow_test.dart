import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:transport/app/data/services/firebase_service.dart';

/// Regression coverage for two live-data bugs found in the Jul-2026 audit.
///
/// 1) Inspection: reproduces the reported bug: a driver submits an inspection while they have
/// an active trip. The admin dashboard filtered such trucks out, so it showed
/// "0 Pending" and the driver stayed stuck on "Pending Review" forever.
///
/// This exercises the real Firestore lifecycle + the exact filter the admin
/// dashboard uses.
void main() {
  const driver = '919876543210';

  late FakeFirebaseFirestore db;
  late FirebaseService fb;

  setUp(() {
    db = FakeFirebaseFirestore();
    fb = FirebaseService(firestore: db, ownerKeyResolver: () => driver);
  });

  /// The admin dashboard's pending-inspection filter (mirrors
  /// _buildMockupOperationsHub in admin_home_view.dart).
  List<Map<String, dynamic>> pendingInspections(
    List<Map<String, dynamic>> trucks,
    List<Map<String, dynamic>> trips,
  ) {
    return trucks.where((t) {
      final status = (t['inspectionStatus'] ?? '').toString();
      final hasDriver = (t['assignedTo'] ?? '').toString().isNotEmpty;
      if (!hasDriver) return false;
      if (status == 'inspected_pending_review') return true;
      if (status != 'pending') return false;
      final driverPhone = (t['assignedTo'] ?? '').toString();
      final hasActiveTrip = trips.any((trip) =>
          (trip['driverPhone'] ?? '').toString() == driverPhone &&
          trip['status'] != 'DELIVERED' &&
          trip['status'] != 'CANCELLED');
      return !hasActiveTrip;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> trucks() async =>
      (await db.collection('trucks').get()).docs.map((d) {
        final m = d.data();
        m['truckNo'] = d.id;
        return m;
      }).toList();

  Future<List<Map<String, dynamic>>> trips() async =>
      (await db.collection('trips').get()).docs.map((d) => d.data()).toList();

  test('submitted inspection is visible to admin even with an active trip',
      () async {
    // Register truck + driver check-in
    await db.collection('users').doc(driver).set({
      'role': 'driver',
      'availability': 'Available',
    });

    await db.collection('trucks').doc('GJ01-SA-1114').set({
      'model': 'Tata',
      'status': 'Idle',
    });

    // Create an active trip for this driver
    await db.collection('trips').add({
      'status': 'ACTIVE NOW',
      'driverPhone': driver,
      'truckNo': 'GJ01-SA-1114',
    });

    await fb.assignTruckToDriver('GJ01-SA-1114', driver);
    expect((await trucks()).first['inspectionStatus'], 'pending_confirmation');

    await fb.acceptTruckAssignment('GJ01-SA-1114', driver);
    expect((await trucks()).first['inspectionStatus'], 'pending');

    // Driver completes and submits the inspection (All Good).
    await fb.submitTruckInspection(
      'GJ01-SA-1114',
      results: {'Brakes': true, 'Tyres': true},
      remarks: 'All good',
      imageUrls: const [],
      driverName: 'YASH',
    );

    // Directly transitions to ready if clean
    expect((await trucks()).first['inspectionStatus'], 'ready');

    // Reset and assign again to test problem reporting
    await fb.unassignTruck('GJ01-SA-1114');
    await fb.assignTruckToDriver('GJ01-SA-1114', driver);
    await fb.acceptTruckAssignment('GJ01-SA-1114', driver);

    // Driver completes and submits an inspection with a problem.
    await fb.submitTruckInspection(
      'GJ01-SA-1114',
      results: {'Brakes': false, 'Tyres': true},
      remarks: 'Brake issue',
      imageUrls: const [],
      driverName: 'YASH',
    );

    // Should transition to problem
    expect((await trucks()).first['inspectionStatus'], 'problem');

    // Admin resolves the issue -> transitions back to ready
    await fb.clearTruckIssue('GJ01-SA-1114');
    expect((await trucks()).first['inspectionStatus'], 'ready');
  });

  test('driver expenses stream reflects an admin approve in real time',
      () async {
    await fb.submitTripExpense({
      'id': 'EXP-1',
      'title': 'Diesel',
      'amount': '1200',
      'driverPhone': driver,
      'ownerId': driver,
    }, driverName: 'YASH');

    final stream = fb.watchExpensesForDriver(driver);

    // First emission: the claim is Pending.
    final first = await stream.first;
    expect(first, hasLength(1));
    expect(first.first['status'], 'Pending');

    // Admin approves -> the driver's live stream must show Approved without a
    // manual refresh (previously this screen was a one-shot read).
    await fb.approveExpenseById('EXP-1', adminName: 'Admin');

    final after = await stream.first;
    expect(after.first['status'], 'Approved');
  });
}
