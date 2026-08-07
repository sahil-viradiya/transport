import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/session_service.dart';


void main() {
  late FakeFirebaseFirestore firestore;
  const driverPhone = '919876543210';

  FirebaseService service() => FirebaseService(
        firestore: firestore,
        ownerKeyResolver: () => driverPhone,
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Return to Transport Station & Parking Confirmation Flow Tests', () {
    test('startReturnJourney sets status to RETURNING_TO_STATION and notifies admin', () async {
      final svc = service();

      await svc.startReturnJourney(
        key: driverPhone,
        driverName: 'Rajesh Kumar',
      );

      final driverDoc = await firestore.collection('drivers').doc(driverPhone).get();
      expect(driverDoc.exists, true);
      expect(driverDoc.data()!['dutyStatus'], 'RETURNING_TO_STATION');
      expect(driverDoc.data()!['returnJourneyStatus'], 'in_transit');
      expect(driverDoc.data()!['canClockOut'], false);

      final notifications = await firestore.collection('notifications').get();
      expect(notifications.docs.length, 1);
      final adminNotif = notifications.docs.first.data();
      expect(adminNotif['toPhone'], 'admin');
      expect(adminNotif['type'], 'return_journey_started');
      expect(adminNotif['body'], contains('Rajesh Kumar'));
    });

    test('submitParkingConfirmation creates confirmation doc, sets PARKING_PENDING and notifies admin', () async {
      final svc = service();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      await svc.submitParkingConfirmation(
        driverId: driverPhone,
        driverName: 'Rajesh Kumar',
        vehicleNo: 'GJ-01-AX-9988',
        photoBytes: dummyBytes,
        latitude: 18.9482,
        longitude: 72.9469,
        address: 'Transport Terminal Station Hub',
        distanceKm: 0.15,
      );

      final driverDoc = await firestore.collection('drivers').doc(driverPhone).get();
      expect(driverDoc.data()!['dutyStatus'], 'PARKING_PENDING');
      expect(driverDoc.data()!['returnJourneyStatus'], 'parking_requested');
      expect(driverDoc.data()!['canClockOut'], false);

      final parkingDocs = await firestore.collection('parking_confirmations').get();
      expect(parkingDocs.docs.length, 1);
      final reqData = parkingDocs.docs.first.data();
      expect(reqData['driverId'], driverPhone);
      expect(reqData['vehicleNo'], 'GJ-01-AX-9988');
      expect(reqData['status'], 'PENDING');
      expect(reqData['distanceKm'], 0.15);

      final notifications = await firestore.collection('notifications').get();
      final adminNotif = notifications.docs.firstWhere((n) => n.data()['type'] == 'parking_confirmation_request');
      expect(adminNotif.data()['toPhone'], 'admin');
    });

    test('approveParkingConfirmation sets status to STATION_VERIFIED and enables clock out', () async {
      final svc = service();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      await svc.submitParkingConfirmation(
        driverId: driverPhone,
        driverName: 'Rajesh Kumar',
        vehicleNo: 'GJ-01-AX-9988',
        photoBytes: dummyBytes,
        latitude: 18.9482,
        longitude: 72.9469,
        address: 'Transport Terminal Station Hub',
        distanceKm: 0.15,
      );

      final parkingDocs = await firestore.collection('parking_confirmations').get();
      final reqId = parkingDocs.docs.first.id;

      await svc.approveParkingConfirmation(driverPhone, reqId, adminName: 'Admin Manager');

      final driverDoc = await firestore.collection('drivers').doc(driverPhone).get();
      expect(driverDoc.data()!['dutyStatus'], 'STATION_VERIFIED');
      expect(driverDoc.data()!['returnJourneyStatus'], 'verified');
      expect(driverDoc.data()!['canClockOut'], true);

      final updatedReq = await firestore.collection('parking_confirmations').doc(reqId).get();
      expect(updatedReq.data()!['status'], 'APPROVED');
      expect(updatedReq.data()!['approvedBy'], 'Admin Manager');

      final notifications = await firestore.collection('notifications').get();
      final driverNotif = notifications.docs.firstWhere((n) => n.data()['type'] == 'parking_approved');
      expect(driverNotif.data()['toPhone'], SessionService.normalizePhone(driverPhone));
    });

    test('rejectParkingConfirmation sets status to RETURNING_TO_STATION and keeps clock out locked', () async {
      final svc = service();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      await svc.submitParkingConfirmation(
        driverId: driverPhone,
        driverName: 'Rajesh Kumar',
        vehicleNo: 'GJ-01-AX-9988',
        photoBytes: dummyBytes,
        latitude: 18.9482,
        longitude: 72.9469,
        address: 'Transport Terminal Station Hub',
        distanceKm: 0.15,
      );

      final parkingDocs = await firestore.collection('parking_confirmations').get();
      final reqId = parkingDocs.docs.first.id;

      await svc.rejectParkingConfirmation(
        driverPhone,
        reqId,
        'Incorrect truck photo provided',
        adminName: 'Admin Manager',
      );

      final driverDoc = await firestore.collection('drivers').doc(driverPhone).get();
      expect(driverDoc.data()!['dutyStatus'], 'RETURNING_TO_STATION');
      expect(driverDoc.data()!['returnJourneyStatus'], 'rejected');
      expect(driverDoc.data()!['canClockOut'], false);

      final updatedReq = await firestore.collection('parking_confirmations').doc(reqId).get();
      expect(updatedReq.data()!['status'], 'REJECTED');
      expect(updatedReq.data()!['rejectionReason'], 'Incorrect truck photo provided');

      final notifications = await firestore.collection('notifications').get();
      final driverNotif = notifications.docs.firstWhere((n) => n.data()['type'] == 'parking_rejected');
      expect(driverNotif.data()['toPhone'], SessionService.normalizePhone(driverPhone));
    });
  });
}

