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

    test('delivery saves POD url + remarks and marks trip DELIVERED', () async {
      final svc = service();
      await svc.saveTrip('t1', {'truckNo': 'GJ-01'});

      await svc.saveProofOfDeliveryDetails(
          't1', 'https://example.com/pod.jpg', 'Handed to gate keeper');

      final data = (await firestore.collection('trips').doc('t1').get()).data()!;
      expect(data['status'], 'DELIVERED');
      expect(data['isActive'], false);
      expect(data['podUrl'], 'https://example.com/pod.jpg');
      expect(data['remarks'], 'Handed to gate keeper');
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
}
