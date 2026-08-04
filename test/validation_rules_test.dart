import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/core/errors/validation_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive System Validation Rules', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();

      firestore = FakeFirebaseFirestore();

      final storage = StorageService();
      await storage.init();
      Get.put<StorageService>(storage);

      final session = SessionService(storage: storage);
      await session.init();
      Get.put<SessionService>(session);

      service = FirebaseService(firestore: firestore, ownerKeyResolver: () => '+919876543210');
      await service.init();
      Get.put<FirebaseService>(service);
    });

    test('Rule 1: Duplicate truck number creation is blocked', () async {
      await service.saveTruck('GJ-01-AX-9988', {'model': 'Tata Signa'});

      // Attempt to save same truck number with different spacing/case
      expect(
        () async => await service.saveTruck('gj01ax9988', {'model': 'Ashok Leyland'}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 2: Cannot assign truck to driver who is on leave', () async {
      const driverPhone = '+919111111111';
      await firestore.collection('users').doc(driverPhone).set({
        'phone': driverPhone,
        'onLeave': true,
      });

      expect(
        () async => await service.assignTruckToDriver('GJ-01-AX-9988', driverPhone),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 3: Cannot assign same truck to 2 active drivers simultaneously', () async {
      const driver1 = '+919111111111';
      const driver2 = '+919222222222';
      const truckNo = 'GJ-01-AX-9988';

      await firestore.collection('users').doc(driver1).set({'phone': driver1, 'onLeave': false, 'checkedIn': true, 'availability': 'available'});
      await firestore.collection('users').doc(driver2).set({'phone': driver2, 'onLeave': false, 'checkedIn': true, 'availability': 'available'});

      await service.assignTruckToDriver(truckNo, driver1);

      // Attempting to assign same truck to driver2 without unassigning should fail
      expect(
        () async => await service.assignTruckToDriver(truckNo, driver2),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 4: Cannot assign trip to driver on leave', () async {
      const driverPhone = '+919111111111';
      await firestore.collection('users').doc(driverPhone).set({
        'phone': driverPhone,
        'onLeave': true,
      });

      expect(
        () async => await service.assignTripToDriver('TRP-101', {
          'driverPhone': driverPhone,
          'pickupCity': 'Mumbai',
          'dropCity': 'Delhi',
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 5: Cannot assign same active trip to multiple drivers', () async {
      const driver1 = '+919111111111';
      const driver2 = '+919222222222';
      const tripId = 'TRP-101';

      await firestore.collection('users').doc(driver1).set({'phone': driver1, 'onLeave': false});
      await firestore.collection('users').doc(driver2).set({'phone': driver2, 'onLeave': false});

      await service.assignTripToDriver(tripId, {
        'driverPhone': driver1,
        'pickupCity': 'Mumbai',
        'dropCity': 'Delhi',
      });

      // Attempting to assign same trip to driver2 while driver1 trip is active should fail
      expect(
        () async => await service.assignTripToDriver(tripId, {
          'driverPhone': driver2,
          'pickupCity': 'Mumbai',
          'dropCity': 'Delhi',
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 6: Trip pickup and drop cities cannot be identical', () async {
      expect(
        () async => await service.saveTrip('TRP-102', {
          'pickupCity': 'Ahmedabad',
          'dropCity': 'Ahmedabad',
          'freightAmount': 5000,
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 7: Expense amount must be greater than zero', () async {
      expect(
        () async => await service.submitTripExpense({
          'title': 'Fuel Expense',
          'amount': 0,
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule 8: deleteTruck permanently removes truck from database', () async {
      const truckNo = 'GJ-01-AX-7777';
      await service.saveTruck(truckNo, {'model': 'Tata Signa', 'truckNo': truckNo});

      var trucks = await firestore.collection('trucks').get();
      expect(trucks.docs.any((d) => d.id == truckNo || d.data()['truckNo'] == truckNo), true);

      await service.deleteTruck(truckNo);

      trucks = await firestore.collection('trucks').get();
      expect(trucks.docs.any((d) => d.id == truckNo || d.data()['truckNo'] == truckNo), false);
    });

    test('Rule 9: Cannot assign truck to driver who is Off Duty (not clocked in)', () async {
      const driverPhone = '+919333333333';
      await firestore.collection('users').doc(driverPhone).set({
        'phone': driverPhone,
        'onLeave': false,
        'checkedIn': false,
        'availability': 'off_duty',
      });

      expect(
        () async => await service.assignTruckToDriver('GJ-01-AX-9988', driverPhone),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
