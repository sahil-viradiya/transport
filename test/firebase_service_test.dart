import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/session_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  String owner = '';

  // A service bound to an in-memory Firestore whose "current owner" we can
  // flip between calls to simulate different signed-in users.
  FirebaseService service() =>
      FirebaseService(firestore: firestore, ownerKeyResolver: () => owner);

  const ownerA = '+919876543210';
  const ownerB = '+918000000000';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    owner = ownerA;
  });

  group('SessionService.normalizePhone', () {
    test('strips spaces, dashes and parentheses', () {
      expect(SessionService.normalizePhone('+91 98765-43210'), '+919876543210');
      expect(SessionService.normalizePhone('+91 (987) 654 3210'), '+919876543210');
      expect(SessionService.normalizePhone('+919876543210'), '+919876543210');
    });
  });

  group('Trip ownership', () {
    test('saveTrip stamps the current ownerId automatically', () async {
      final svc = service();
      await svc.saveTrip('t1', {'truckNo': 'GJ-01-AB-1234'});

      final doc = await firestore.collection('trips').doc('t1').get();
      expect(doc.data()!['ownerId'], ownerA);
    });

    test('getTripsForOwner returns only the signed-in owner\'s trips', () async {
      final svc = service();
      await svc.saveTrip('t1', {'truckNo': 'GJ-01'});
      await svc.saveTrip('t2', {'truckNo': 'GJ-02'});

      owner = ownerB;
      await svc.saveTrip('t3', {'truckNo': 'MH-09'});

      owner = ownerA;
      final aTrips = await svc.getTripsForOwner();
      expect(aTrips.map((t) => t.id).toSet(), {'t1', 't2'});

      owner = ownerB;
      final bTrips = await svc.getTripsForOwner();
      expect(bTrips.map((t) => t.id).toSet(), {'t3'});
    });

    test('watchTripsForOwner emits owner-scoped trips reactively', () async {
      final svc = service();
      await svc.saveTrip('t1', {'truckNo': 'GJ-01'});

      final trips = await svc.watchTripsForOwner(ownerA).first;
      expect(trips.length, 1);
      expect(trips.first.truckNo, 'GJ-01');
    });

    test('admin-assigned trip reaches the driver, not the admin', () async {
      const adminPhone = '+919999999999';
      final svc = service();

      // Admin is signed in and assigns a trip to a driver, typing the phone
      // with spaces in the form.
      owner = adminPhone;
      await svc.saveTrip('TRP-1', {
        'truckNo': 'GJ-01',
        'driverPhone': '+91 98765 43210',
        'pickupCity': 'Surat',
      });

      // The assigned driver sees it (phone normalised to match their key)...
      final driverTrips = await svc.getTripsForOwner(ownerA);
      expect(driverTrips.map((t) => t.id), ['TRP-1']);

      // ...but it never leaks into the admin's own owner-scoped trips.
      final adminTrips = await svc.getTripsForOwner(adminPhone);
      expect(adminTrips, isEmpty);
    });

    test('watchAllTrips streams every trip for the admin dashboard', () async {
      final svc = service();
      owner = ownerA;
      await svc.saveTrip('t1', {'truckNo': 'GJ-01'});
      owner = ownerB;
      await svc.saveTrip('t2', {'truckNo': 'MH-09'});

      final all = await svc.watchAllTrips().first;
      expect(all.map((t) => t.id).toSet(), {'t1', 't2'});
    });
  });

  group('Milestone updates', () {
    test('updateTripMilestone appends an immutable log entry and sets status',
        () async {
      final svc = service();
      await svc.saveTrip('t1', {'truckNo': 'GJ-01', 'currentMilestone': 1});

      await svc.updateTripMilestone('t1', 2,
          status: 'ACTIVE NOW', locationName: 'Aslali Pickup');

      final doc = await firestore.collection('trips').doc('t1').get();
      final data = doc.data()!;
      expect(data['currentMilestone'], 2);
      expect(data['status'], 'ACTIVE NOW');
      expect(data['isActive'], true);

      final log = data['milestonesLog'] as List;
      expect(log.length, 1);
      expect(log.first['milestone'], 2);
      expect(log.first['label'], 'Reached Pickup');
      expect(log.first['address'], 'Aslali Pickup');
    });

    test('starting a trip deactivates the owner\'s other active trip', () async {
      final svc = service();
      await svc.saveTrip('t1', {'truckNo': 'GJ-01', 'isActive': true, 'status': 'ACTIVE NOW'});
      await svc.saveTrip('t2', {'truckNo': 'GJ-02', 'isActive': false});

      await svc.updateTripMilestone('t2', 2, status: 'ACTIVE NOW');

      final t1 = (await firestore.collection('trips').doc('t1').get()).data()!;
      final t2 = (await firestore.collection('trips').doc('t2').get()).data()!;
      expect(t1['isActive'], false);
      expect(t1['status'], 'ASSIGNED');
      expect(t2['isActive'], true);
    });

    test('POD save keeps trip NOT delivered — admin must verify + approve first',
        () async {
      final svc = service();
      await svc.saveTrip(
          't1', {'truckNo': 'GJ-01', 'status': 'ACTIVE NOW', 'isActive': true});

      // Driver uploads proof → only podUrl/remarks saved, status unchanged.
      await svc.saveProofOfDeliveryDetails(
          't1', 'https://example.com/pod.jpg', 'Handed to gate keeper');
      var data = (await firestore.collection('trips').doc('t1').get()).data()!;
      expect(data['status'], 'ACTIVE NOW');
      expect(data['podUrl'], 'https://example.com/pod.jpg');
      expect(data['remarks'], 'Handed to gate keeper');

      // Delivery requested → awaiting admin verification.
      await svc.requestDelivery('t1', location: 'Drop Gate');
      data = (await firestore.collection('trips').doc('t1').get()).data()!;
      expect(data['status'], 'DELIVERY_REQUESTED');

      // Admin verifies the proof and approves → NOW it's delivered.
      await svc.approveDelivery('t1');
      data = (await firestore.collection('trips').doc('t1').get()).data()!;
      expect(data['status'], 'DELIVERED');
      expect(data['isActive'], false);
    });
  });

  group('Owner profile isolation', () {
    test('driver profile is keyed to the signed-in owner', () async {
      final svc = service();
      await svc.updateDriverProfile({'driverName': 'Owner A', 'vehicleNo': 'GJ-01'});

      owner = ownerB;
      await svc.updateDriverProfile({'driverName': 'Owner B', 'vehicleNo': 'MH-09'});

      owner = ownerA;
      final a = await svc.getDriverProfile();
      expect(a['driverName'], 'Owner A');
      expect(a['vehicleNo'], 'GJ-01');

      owner = ownerB;
      final b = await svc.getDriverProfile();
      expect(b['driverName'], 'Owner B');
    });

    test('emergency contact writes go to the owner doc', () async {
      final svc = service();
      await svc.updateEmergencyContact('Sunita', 'Wife', '+919999999999');

      final doc = await firestore.collection('drivers').doc(ownerA).get();
      expect(doc.data()!['emergencyName'], 'Sunita');
      expect(doc.data()!['phone'], '+919999999999');
    });
  });

  group('Expenses', () {
    test('getExpensesForDriver tolerates unnormalised phone input', () async {
      final svc = service();
      await svc.saveExpense({
        'id': 'EXP-1',
        'driverPhone': ownerA,
        'title': 'Diesel',
        'amount': '₹8,500',
      });

      final result = await svc.getExpensesForDriver('+91 98765 43210');
      expect(result.length, 1);
      expect(result.first['title'], 'Diesel');
    });

    test('saveExpense stamps ownerId', () async {
      final svc = service();
      await svc.saveExpense({'id': 'EXP-2', 'driverPhone': ownerA, 'amount': '₹100'});
      final doc = await firestore.collection('expenses').doc('EXP-2').get();
      expect(doc.data()!['ownerId'], ownerA);
    });
  });

  group('Demo seeding for a new owner', () {
    test('creates a private, populated starter workspace', () async {
      final svc = service();
      await svc.seedDemoDataForOwner(ownerA, name: 'Ramesh Patel');

      final profile = await firestore.collection('drivers').doc(ownerA).get();
      expect(profile.data()!['name'], 'Ramesh Patel');
      expect(profile.data()!['seededDemo'], true);

      final trips = await svc.getTripsForOwner(ownerA);
      expect(trips.length, 2);
      expect(trips.every((t) => t.driverPhone == ownerA), true);

      final trucks = await svc.getTrucksForOwner(ownerA);
      expect(trucks.length, 1);

      final expenses = await svc.getExpensesForDriver(ownerA);
      expect(expenses.length, 1);
    });

    test('is idempotent — running twice does not duplicate or re-seed', () async {
      final svc = service();
      await svc.seedDemoDataForOwner(ownerA, name: 'Ramesh Patel');

      // Owner edits their name; a second seed must not clobber it.
      await svc.updateDriverProfile({'name': 'Ramesh Bhai'}, ownerA);
      await svc.seedDemoDataForOwner(ownerA, name: 'Ramesh Patel');

      final profile = await firestore.collection('drivers').doc(ownerA).get();
      expect(profile.data()!['name'], 'Ramesh Bhai');

      final trips = await svc.getTripsForOwner(ownerA);
      expect(trips.length, 2);
    });

    test('seeded data of one owner is invisible to another owner', () async {
      final svc = service();
      await svc.seedDemoDataForOwner(ownerA, name: 'Owner A');

      owner = ownerB;
      final bTrips = await svc.getTripsForOwner();
      expect(bTrips, isEmpty);
    });
  });

  group('Trip confirmation workflow', () {
    const admin = '+919999999999';

    test('assignTripToDriver writes PENDING + notifies the driver', () async {
      owner = admin; // admin is signed in
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {
        'driverPhone': ownerA,
        'pickupCity': 'Surat',
        'dropCity': 'Rajkot',
      });

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'PENDING');
      expect(trip['ownerId'], ownerA);
      expect(trip['assignedBy'], admin);

      final driverNotes = await svc.getNotifications(ownerA);
      expect(driverNotes.length, 1);
      expect(driverNotes.first['type'], 'trip_assigned');
      expect(driverNotes.first['read'], false);
    });

    test('acceptTrip marks ASSIGNED and notifies the admin who assigned it',
        () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {'driverPhone': ownerA});

      owner = ownerA; // driver acts
      await svc.acceptTrip('TRP-1', driverName: 'Rajesh');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'ASSIGNED');
      expect(trip['confirmedByDriver'], true);

      final adminNotes = await svc.getNotifications(admin);
      expect(adminNotes.any((n) => n['type'] == 'trip_accepted'), true);
    });

    test('rejectTrip marks REJECTED and notifies the admin with a reason',
        () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {'driverPhone': ownerA});

      owner = ownerA;
      await svc.rejectTrip('TRP-1', reason: 'Truck breakdown', driverName: 'Rajesh');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'REJECTED');

      final adminNotes = await svc.getNotifications(admin);
      final rej = adminNotes.firstWhere((n) => n['type'] == 'trip_rejected');
      expect(rej['body'].toString().contains('Truck breakdown'), true);
    });
  });

  group('Load approval gate', () {
    const admin = '+919999999999';

    test('requestLoadApproval → LOAD_REQUESTED (not active) + notifies admin',
        () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1',
          {'driverPhone': ownerA, 'pickupLocation': 'Aslali'});
      owner = ownerA;
      await svc.acceptTrip('TRP-1', driverName: 'Rajesh');

      await svc.requestLoadApproval('TRP-1',
          pickupLocation: 'Aslali', driverName: 'Rajesh');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'LOAD_REQUESTED');
      expect(trip['isActive'], false);

      final adminNotes = await svc.getNotifications(admin);
      expect(adminNotes.any((n) => n['type'] == 'load_request'), true);
    });

    test('approveLoad → ACTIVE NOW + notifies the driver', () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver(
          'TRP-1', {'driverPhone': ownerA, 'dropCity': 'Rajkot'});
      owner = ownerA;
      await svc.acceptTrip('TRP-1');
      await svc.requestLoadApproval('TRP-1', driverName: 'Rajesh');

      await svc.approveLoad('TRP-1', adminName: 'Admin');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'ACTIVE NOW');
      expect(trip['isActive'], true);

      final driverNotes = await svc.getNotifications(ownerA);
      expect(driverNotes.any((n) => n['type'] == 'trip_activated'), true);
    });

    test('approve is one-time — a second approveLoad is a no-op', () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver(
          'TRP-1', {'driverPhone': ownerA, 'dropCity': 'Rajkot'});
      owner = ownerA;
      await svc.acceptTrip('TRP-1');
      await svc.requestLoadApproval('TRP-1');

      await svc.approveLoad('TRP-1');
      final firstCount = (await svc.getNotifications(ownerA))
          .where((n) => n['type'] == 'trip_activated')
          .length;

      // Trip is ACTIVE NOW → the guard makes this a no-op (no duplicate notify).
      await svc.approveLoad('TRP-1');
      final secondCount = (await svc.getNotifications(ownerA))
          .where((n) => n['type'] == 'trip_activated')
          .length;

      expect(secondCount, firstCount);
    });

    test('rejectLoad → status REJECTED + notifies the driver', () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {'driverPhone': ownerA});
      owner = ownerA;
      await svc.acceptTrip('TRP-1');
      await svc.requestLoadApproval('TRP-1');

      await svc.rejectLoad('TRP-1', reason: 'Wrong goods');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'REJECTED');
      expect(trip['isActive'], false);

      final driverNotes = await svc.getNotifications(ownerA);
      final rej = driverNotes.firstWhere((n) => n['type'] == 'load_rejected');
      expect(rej['body'].toString().contains('Wrong goods'), true);
    });
  });

  group('Vendor journey (assign → on-the-way → loading → destination gate)', () {
    const admin = '+919999999999';

    Future<FirebaseService> setupAssigned(FirebaseService svc) async {
      owner = admin;
      await svc.assignTripToDriver('TRP-1', {
        'driverPhone': ownerA,
        'vendorName': 'Shree Aggregates',
        'vendorLocation': 'Aslali Quarry',
        'materialName': 'Kapchi',
        'passHolderName': 'Ramesh',
        'royaltyName': 'Gujarat Minerals',
        'loadingPassId': '12345678',
        'pickupDistrict': 'Ahmedabad',
      });
      owner = ownerA;
      await svc.acceptTrip('TRP-1');
      return svc;
    }

    test('vendor/material fields persist and parse into the model', () async {
      final svc = await setupAssigned(service());
      final trip =
          (await svc.getTripsForOwner(ownerA)).firstWhere((t) => t.id == 'TRP-1');
      expect(trip.vendorName, 'Shree Aggregates');
      expect(trip.materialName, 'Kapchi');
      expect(trip.loadingPassId, '12345678');
      expect(trip.pickupDistrict, 'Ahmedabad');
    });

    test('startToVendor → EN_ROUTE_VENDOR + admin sees on-the-way', () async {
      final svc = await setupAssigned(service());

      await svc.startToVendor('TRP-1', driverName: 'Rajesh');

      final t = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(t['status'], 'EN_ROUTE_VENDOR');
      final notes = await svc.getNotifications(admin);
      expect(notes.any((n) => n['type'] == 'vendor_way'), true);
    });

    test('startLoading → LOADING + admin pinged to set destination', () async {
      final svc = await setupAssigned(service());
      await svc.startToVendor('TRP-1');

      await svc.startLoading('TRP-1',
          location: 'Aslali Quarry', driverName: 'Rajesh');

      final t = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(t['status'], 'LOADING');
      final notes = await svc.getNotifications(admin);
      expect(notes.any((n) => n['type'] == 'loading_started'), true);
    });

    test('approveLoad is blocked until the destination is set', () async {
      final svc = await setupAssigned(service());
      await svc.startToVendor('TRP-1');
      await svc.startLoading('TRP-1');
      await svc.requestLoadApproval('TRP-1');

      // No destination yet → blocked with a message, status unchanged.
      owner = admin;
      final err = await svc.approveLoad('TRP-1');
      expect(err, isNotNull);
      var t = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(t['status'], 'LOAD_REQUESTED');

      // Admin sets the destination → approve succeeds → ACTIVE NOW.
      await svc.setTripDestination('TRP-1',
          dropCity: 'Rajkot', dropLocation: 'Mavdi Site');
      final ok = await svc.approveLoad('TRP-1');
      expect(ok, isNull);
      t = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(t['status'], 'ACTIVE NOW');
      expect(t['dropCity'], 'Rajkot');
    });

    test('remindSetDestination fires once and only while destination missing',
        () async {
      final svc = await setupAssigned(service());
      await svc.startLoading('TRP-1');
      await svc.requestLoadApproval('TRP-1');

      expect(await svc.remindSetDestination('TRP-1'), true);
      // Second reminder suppressed by the flag.
      expect(await svc.remindSetDestination('TRP-1'), false);

      final notes = await svc.getNotifications(admin);
      expect(
          notes.where((n) => n['type'] == 'set_destination_reminder').length, 1);
    });
  });

  group('Delivery approval gate', () {
    const admin = '+919999999999';

    test('requestDelivery → DELIVERY_REQUESTED + notifies admin with location',
        () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {'driverPhone': ownerA});
      owner = ownerA;

      await svc.requestDelivery('TRP-1',
          location: 'Mavdi Chowkdi', latitude: 22.28, longitude: 70.79,
          driverName: 'Rajesh');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'DELIVERY_REQUESTED');
      expect(trip['currentAddress'], 'Mavdi Chowkdi');

      final adminNotes = await svc.getNotifications(admin);
      final n = adminNotes.firstWhere((n) => n['type'] == 'delivery_request');
      expect(n['body'].toString().contains('Mavdi Chowkdi'), true);
    });

    test('approveDelivery → DELIVERED + notifies driver', () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {'driverPhone': ownerA});
      owner = ownerA;
      await svc.requestDelivery('TRP-1', location: 'Drop');

      await svc.approveDelivery('TRP-1');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'DELIVERED');
      expect(trip['isActive'], false);

      final driverNotes = await svc.getNotifications(ownerA);
      expect(driverNotes.any((n) => n['type'] == 'delivery_approved'), true);
    });

    test('rejectDelivery → status REJECTED', () async {
      owner = admin;
      final svc = service();
      await svc.assignTripToDriver('TRP-1', {'driverPhone': ownerA});
      owner = ownerA;
      await svc.requestDelivery('TRP-1');

      await svc.rejectDelivery('TRP-1', reason: 'POD missing');

      final trip = (await firestore.collection('trips').doc('TRP-1').get()).data()!;
      expect(trip['status'], 'REJECTED');
      expect(trip['isActive'], false);
      final driverNotes = await svc.getNotifications(ownerA);
      expect(driverNotes.any((n) => n['type'] == 'delivery_rejected'), true);
    });
  });

  group('Trip expenses with proof + approval', () {
    const admin = '+919999999999';
    Future<void> seedAdmin() =>
        firestore.collection('users').doc(admin).set({'role': 'admin'});

    test('submitTripExpense saves Pending + notifies admins', () async {
      await seedAdmin();
      owner = ownerA;
      final svc = service();

      await svc.submitTripExpense({
        'id': 'EXP-1',
        'tripId': 'TRP-1',
        'title': 'Diesel',
        'amount': '₹8,500',
        'receiptUrl': 'https://x/y.jpg',
      }, driverName: 'Rajesh');

      final e = (await firestore.collection('expenses').doc('EXP-1').get()).data()!;
      expect(e['status'], 'Pending');
      expect(e['ownerId'], ownerA);
      expect(e['driverPhone'], ownerA);

      final adminNotes = await svc.getNotifications(admin);
      final note = adminNotes.firstWhere((n) => n['type'] == 'expense_submitted');
      // refId carries the expense id so the detail page can approve/reject it.
      expect(note['refId'], 'EXP-1');
    });

    test('approveExpenseById / rejectExpenseById notify the driver', () async {
      owner = ownerA;
      final svc = service();
      await svc.submitTripExpense(
          {'id': 'EXP-1', 'title': 'Toll', 'amount': '₹200', 'driverPhone': ownerA});

      await svc.approveExpenseById('EXP-1');
      var e = (await firestore.collection('expenses').doc('EXP-1').get()).data()!;
      expect(e['status'], 'Approved');
      expect((await svc.getNotifications(ownerA))
          .any((n) => n['type'] == 'expense_approved'), true);

      await svc.submitTripExpense(
          {'id': 'EXP-2', 'title': 'Puncture', 'amount': '₹500', 'driverPhone': ownerA});
      await svc.rejectExpenseById('EXP-2', reason: 'No bill');
      e = (await firestore.collection('expenses').doc('EXP-2').get()).data()!;
      expect(e['status'], 'Rejected');
      expect((await svc.getNotifications(ownerA))
          .any((n) => n['type'] == 'expense_rejected'), true);
    });
  });

  group('Priority trips', () {
    test('priority flag persists and is parsed back', () async {
      final svc = service();
      await svc.saveTrip('TRP-1', {'driverPhone': ownerA, 'priority': true});
      await svc.saveTrip('TRP-2', {'driverPhone': ownerA});

      final trips = await svc.getTripsForOwner(ownerA);
      expect(trips.firstWhere((t) => t.id == 'TRP-1').priority, true);
      expect(trips.firstWhere((t) => t.id == 'TRP-2').priority, false);
    });
  });

  group('Truck assignment + inspection', () {
    const admin = '+919999999999';
    Future<void> seedAdmin() =>
        firestore.collection('users').doc(admin).set({'role': 'admin'});

    test('assignTruckToDriver → pending inspection + driver notified', () async {
      await seedAdmin();
      owner = admin;
      final svc = service();

      await svc.assignTruckToDriver('GJ-01-AB-1234', '+91 98765 43210',
          model: 'Tata Signa');

      var t = (await firestore.collection('trucks').doc('GJ-01-AB-1234').get())
          .data()!;
      expect(t['assignedTo'], ownerA); // normalized phone
      expect(t['assignedBy'], admin);
      expect(t['inspectionStatus'], 'pending_confirmation');

      await svc.acceptTruckAssignment('GJ-01-AB-1234');
      t = (await firestore.collection('trucks').doc('GJ-01-AB-1234').get())
          .data()!;
      expect(t['inspectionStatus'], 'pending');

      final notes = await svc.getNotifications(ownerA);
      final n = notes.firstWhere((n) => n['type'] == 'truck_assigned');
      expect(n['refId'], 'GJ-01-AB-1234');
    });

    test('reportTruckIssue → problem + admins notified with reason', () async {
      await seedAdmin();
      owner = admin;
      final svc = service();
      await svc.assignTruckToDriver('GJ-01', ownerA);
      await svc.acceptTruckAssignment('GJ-01');

      owner = ownerA;
      await svc.reportTruckIssue('GJ-01',
          reason: 'Tyre puncture', imageUrl: 'https://x/issue.jpg',
          driverName: 'Rajesh');

      final t =
          (await firestore.collection('trucks').doc('GJ-01').get()).data()!;
      expect(t['inspectionStatus'], 'problem');
      expect(t['inspectionIssue'], 'Tyre puncture');
      expect(t['inspectionIssueImage'], 'https://x/issue.jpg');

      final adminNotes = await svc.getNotifications(admin);
      final n = adminNotes.firstWhere((n) => n['type'] == 'truck_issue');
      expect(n['body'].toString().contains('Tyre puncture'), true);
    });

    test('acceptTruck → ready (issue cleared) + admins notified', () async {
      await seedAdmin();
      owner = admin;
      final svc = service();
      await svc.assignTruckToDriver('GJ-01', ownerA);
      await svc.acceptTruckAssignment('GJ-01');
      owner = ownerA;
      await svc.reportTruckIssue('GJ-01', reason: 'Brake loose');

      await svc.acceptTruck('GJ-01', driverName: 'Rajesh');

      final t =
          (await firestore.collection('trucks').doc('GJ-01').get()).data()!;
      expect(t['inspectionStatus'], 'ready');
      expect(t.containsKey('inspectionIssue'), false);

      final adminNotes = await svc.getNotifications(admin);
      expect(adminNotes.any((n) => n['type'] == 'truck_ready'), true);
    });

    test('watchTruckForDriver streams the assigned truck', () async {
      owner = admin;
      final svc = service();
      await svc.assignTruckToDriver('GJ-07', ownerA);

      final t = await svc.watchTruckForDriver('+91 98765 43210').first;
      expect(t, isNotNull);
      expect(t!['truckNo'], 'GJ-07');

      final none = await svc.watchTruckForDriver(ownerB).first;
      expect(none, isNull);
    });
  });

  group('Notifications', () {
    test('are recipient-scoped by phone', () async {
      final svc = service();
      await svc.createNotification(
          toPhone: ownerA, title: 'A', body: 'for A', type: 'info');
      await svc.createNotification(
          toPhone: ownerB, title: 'B', body: 'for B', type: 'info');

      final a = await svc.getNotifications(ownerA);
      final b = await svc.getNotifications(ownerB);
      expect(a.length, 1);
      expect(a.first['title'], 'A');
      expect(b.length, 1);
      expect(b.first['title'], 'B');
    });

    test('markNotificationRead / markAllNotificationsRead flip the flag',
        () async {
      final svc = service();
      await svc.createNotification(toPhone: ownerA, title: '1', body: 'x');
      await svc.createNotification(toPhone: ownerA, title: '2', body: 'y');

      var notes = await svc.getNotifications(ownerA);
      expect(notes.where((n) => n['read'] == false).length, 2);

      await svc.markNotificationRead(notes.first['id']);
      notes = await svc.getNotifications(ownerA);
      expect(notes.where((n) => n['read'] == false).length, 1);

      await svc.markAllNotificationsRead(ownerA);
      notes = await svc.getNotifications(ownerA);
      expect(notes.where((n) => n['read'] == false).length, 0);
    });

    test('watchNotifications streams only the recipient\'s notes', () async {
      final svc = service();
      await svc.createNotification(toPhone: ownerA, title: 'A1', body: 'x');
      await svc.createNotification(toPhone: ownerB, title: 'B1', body: 'y');

      final list = await svc.watchNotifications(ownerA).first;
      expect(list.length, 1);
      expect(list.first['title'], 'A1');
    });
  });

  group('Driver check-in / check-out', () {
    const admin = '+919999999999';

    Future<void> seedAdmin() =>
        firestore.collection('users').doc(admin).set({'role': 'admin'});

    test('checkIn marks the driver Available with location + notifies admin',
        () async {
      await seedAdmin();
      final svc = service();

      await svc.checkIn(ownerA,
          latitude: 21.17, longitude: 72.83, address: 'Surat Depot',
          driverName: 'Rajesh');

      final u = (await firestore.collection('users').doc(ownerA).get()).data()!;
      expect(u['availability'], 'available');
      expect(u['checkedIn'], true);
      expect(u['checkInAddress'], 'Surat Depot');
      expect(u['checkInLatitude'], 21.17);

      // Mirrored onto the driver profile doc too.
      final d = (await firestore.collection('drivers').doc(ownerA).get()).data()!;
      expect(d['availability'], 'available');

      // Admin was notified.
      final adminNotes = await svc.getNotifications(admin);
      expect(adminNotes.any((n) => n['type'] == 'check_in'), true);
    });

    test('checkOut marks the driver Off Duty + notifies admin', () async {
      await seedAdmin();
      final svc = service();
      await svc.checkIn(ownerA,
          latitude: 1, longitude: 2, address: 'X', driverName: 'Rajesh');

      await svc.checkOut(ownerA, driverName: 'Rajesh');

      final u = (await firestore.collection('users').doc(ownerA).get()).data()!;
      expect(u['availability'], 'off_duty');
      expect(u['checkedIn'], false);

      final adminNotes = await svc.getNotifications(admin);
      expect(adminNotes.any((n) => n['type'] == 'check_out'), true);
    });

    test('notifyAdmins reaches every admin, not drivers', () async {
      await seedAdmin();
      await firestore.collection('users').doc('+918111111111').set({'role': 'admin'});
      await firestore.collection('users').doc(ownerA).set({'role': 'driver'});
      final svc = service();

      await svc.notifyAdmins(title: 'T', body: 'B', type: 'info');

      expect((await svc.getNotifications(admin)).length, 1);
      expect((await svc.getNotifications('+918111111111')).length, 1);
      expect((await svc.getNotifications(ownerA)).length, 0);
    });

    test('watchAllUsers streams the live user directory', () async {
      await seedAdmin();
      await firestore.collection('users').doc(ownerA).set(
          {'role': 'driver', 'availability': 'available'});
      final svc = service();

      final users = await svc.watchAllUsers().first;
      final driver = users.firstWhere((u) => u['phone'] == ownerA);
      expect(driver['availability'], 'available');
    });
  });
}
