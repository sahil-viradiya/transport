import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/app/data/services/session_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseService firebaseService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    firebaseService = FirebaseService(
      firestore: firestore,
      ownerKeyResolver: () => '919876543210',
    );
  });

  group('Auth Existing Driver Lookup & UID Linking Tests', () {
    test('Finds driver created from Admin Panel with driverPhone field without UID', () async {
      // Simulate Admin Panel creating a driver doc in `drivers` collection
      await firestore.collection('drivers').doc('driver_doc_101').set({
        'driverName': 'Ramesh Singh',
        'driverPhone': '+91 98765 43210',
        'role': 'Driver',
        'uid': null,
      });

      final userData = await firebaseService.getUserData('+919876543210');
      expect(userData, isNotNull);
      expect(userData!['name'] ?? userData['driverName'], 'Ramesh Singh');
      expect(userData['docId'], 'driver_doc_101');
      expect(userData['role'].toString().toLowerCase(), 'driver');
    });

    test('Finds driver created from Admin Panel with phoneNumber field', () async {
      await firestore.collection('drivers').doc('919876543211').set({
        'name': 'Suresh Kumar',
        'phoneNumber': '919876543211',
        'role': 'driver',
      });

      final userData = await firebaseService.getUserData('9876543211');
      expect(userData, isNotNull);
      expect(userData!['name'], 'Suresh Kumar');
      expect(userData['docId'], '919876543211');
    });

    test('Finds driver created in users collection by doc ID or phone field', () async {
      await firestore.collection('users').doc('919876543212').set({
        'name': 'Amit Shah',
        'phone': '+919876543212',
        'role': 'driver',
      });

      final userData = await firebaseService.getUserData('+919876543212');
      expect(userData, isNotNull);
      expect(userData!['name'], 'Amit Shah');
    });

    test('Links empty UID to existing Driver doc without creating duplicates', () async {
      await firestore.collection('drivers').doc('driver_doc_102').set({
        'driverName': 'Vikram Patel',
        'driverPhone': '+919876543213',
        'role': 'driver',
        'uid': '',
      });

      final userData = await firebaseService.getUserData('9876543213');
      expect(userData, isNotNull);
      final docId = userData!['docId'] as String;

      const newAuthUid = 'firebase_auth_uid_xyz123';
      await firebaseService.linkUserUid('919876543213', newAuthUid, userData);

      final updatedDoc = await firestore.collection('drivers').doc(docId).get();
      expect(updatedDoc.exists, isTrue);
      expect(updatedDoc.data()!['uid'], newAuthUid);

      final reFetched = await firebaseService.getUserData('+919876543213');
      expect(reFetched, isNotNull);
      expect(reFetched!['uid'], newAuthUid);
    });

    test('Preserves existing UID when already present', () async {
      const existingUid = 'uid_already_set_789';
      await firestore.collection('drivers').doc('919876543214').set({
        'name': 'Dinesh Verma',
        'phone': '919876543214',
        'role': 'driver',
        'uid': existingUid,
      });

      final userData = await firebaseService.getUserData('919876543214');
      expect(userData, isNotNull);
      expect(userData!['uid'], existingUid);
    });

    test('Returns null for brand-new phone number not in Firestore', () async {
      final userData = await firebaseService.getUserData('+919999999999');
      expect(userData, isNull);
    });
  });
}
