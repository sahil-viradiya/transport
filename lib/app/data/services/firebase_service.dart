import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:transport/app/modules/trips/controllers/trips_controller.dart';
import 'package:transport/app/modules/profile/controllers/profile_controller.dart';
import 'package:flutter/material.dart';

class FirebaseService extends GetxService {
  // Set to true to bypass Firebase Storage limitations (Blaze plan verification) and return public mock URLs instead
  static const bool useMockStorage = true;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<FirebaseService> init() async {
    return this;
  }

  // Fetch all trips (with auto pre-seed if Firestore is empty)
  Future<List<TripItemModel>> getTrips() async {
    try {
      final snapshot = await _db.collection('trips').get();
      if (snapshot.docs.isEmpty) {
        await seedMockTrips();
        return getTrips();
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TripItemModel(
          id: doc.id,
          truckNo: data['truckNo'] ?? '',
          status: data['status'] ?? '',
          pickupCity: data['pickupCity'] ?? '',
          pickupLocation: data['pickupLocation'] ?? '',
          dropCity: data['dropCity'] ?? '',
          dropLocation: data['dropLocation'] ?? '',
          date: data['date'] ?? '',
          tabType: data['tabType'] ?? '',
          isActive: data['isActive'] ?? false,
          remainingDistance: data['remainingDistance'] ?? '',
          estimatedTime: data['estimatedTime'] ?? '',
          currentAddress: data['currentAddress'] ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Pre-seed Firestore trips if empty
  Future<void> seedMockTrips() async {
    final mockTrips = [
      {
        'truckNo': 'MH-12-BV-0045',
        'status': 'ACTIVE NOW',
        'pickupCity': 'Mumbai',
        'pickupLocation': 'JNPT Terminal',
        'dropCity': 'Nagpur',
        'dropLocation': 'Mihan Hub',
        'date': '24 Oct, 08:30 AM',
        'tabType': 'Today',
        'isActive': true,
        'currentMilestone': 2,
      },
      {
        'truckNo': 'HR-55-AN-9912',
        'status': 'ASSIGNED',
        'pickupCity': 'Pune',
        'pickupLocation': 'Chakan Plant',
        'dropCity': 'Mumbai',
        'dropLocation': 'Customs Gate 4',
        'date': '24 Oct, 02:00 PM',
        'tabType': 'Today',
        'isActive': false,
        'currentMilestone': 0,
      },
      {
        'truckNo': 'MH-04-ET-1188',
        'status': 'ASSIGNED',
        'pickupCity': 'Nashik',
        'pickupLocation': 'Industrial Area',
        'dropCity': 'Ahmedabad',
        'dropLocation': 'Transport Nagar',
        'date': '25 Oct, 06:00 AM',
        'tabType': 'Upcoming',
        'isActive': false,
        'currentMilestone': 0,
      }
    ];

    for (var i = 0; i < mockTrips.length; i++) {
      final docId = i == 0 ? 'TRP-9021-X' : (i == 1 ? 'TRP-8842-B' : 'TRP-7761-Z');
      await _db.collection('trips').doc(docId).set(mockTrips[i]);
    }
  }

  // Update trip milestones & status in Firestore
  Future<void> updateTripMilestone(String tripId, int milestone, {String? status}) async {
    try {
      if (status == 'ACTIVE NOW') {
        // Query other trips that are active and deactivate them
        final activeSnapshot = await _db.collection('trips').where('isActive', isEqualTo: true).get();
        for (var doc in activeSnapshot.docs) {
          if (doc.id != tripId) {
            await doc.reference.set({
              'status': 'ASSIGNED',
              'isActive': false,
            }, SetOptions(merge: true));
          }
        }
      }

      final updates = <String, dynamic>{
        'currentMilestone': milestone,
      };
      if (status != null) {
        updates['status'] = status;
        if (status == 'ACTIVE NOW') {
          updates['isActive'] = true;
        } else if (status == 'DELIVERED') {
          updates['isActive'] = false;
        }
      }
      await _db.collection('trips').doc(tripId).set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  // Upload POD scanned photo to Firebase Storage
  Future<String> uploadProofOfDelivery(String tripId, String filePath) async {
    try {
      if (useMockStorage) {
        if (filePath.isNotEmpty && !filePath.startsWith('http') && await File(filePath).exists()) {
          return filePath;
        }
        return 'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=600';
      }
      if (filePath == 'receipt_scan_042.jpg' || !await File(filePath).exists()) {
        // Simulation mode fallback URL
        return 'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=600';
      }
      final file = File(filePath);
      final ref = _storage.ref().child('proof_of_delivery').child('$tripId.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('------------------------------------------------------------');
      debugPrint('WARNING: Firebase Storage upload failed for Proof of Delivery: $e');
      debugPrint('If you see a 404 Not Found error, it means your Firebase Storage bucket has not been initialized.');
      debugPrint('To resolve this, please open the Firebase Console, navigate to "Storage", click "Get Started" and enable the bucket.');
      debugPrint('Falling back to local file path.');
      debugPrint('------------------------------------------------------------');
      return filePath;
    }
  }

  // Update Firestore trip record with POD downloads
  Future<void> saveProofOfDeliveryDetails(String tripId, String downloadUrl, String remarks) async {
    try {
      await _db.collection('trips').doc(tripId).set({
        'podUrl': downloadUrl,
        'remarks': remarks,
        'status': 'DELIVERED',
        'isActive': false,
        'currentMilestone': 4,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Update trip current location in Firestore
  Future<void> updateTripLocation(
    String tripId, 
    double latitude, 
    double longitude, 
    String address, {
    String? remainingDistance,
    String? estimatedTime,
  }) async {
    try {
      final updates = <String, dynamic>{
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'currentAddress': address,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      };
      if (remainingDistance != null) {
        updates['remainingDistance'] = remainingDistance;
      }
      if (estimatedTime != null) {
        updates['estimatedTime'] = estimatedTime;
      }
      await _db.collection('trips').doc(tripId).set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  // Update driver current location in Firestore
  Future<void> updateDriverLocation(double latitude, double longitude, String address) async {
    try {
      await _db.collection('drivers').doc('rajesh_kumar').set({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'currentAddress': address,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Fetch driver profile (with auto pre-seed if Firestore is empty)
  Future<Map<String, dynamic>> getDriverProfile() async {
    try {
      final doc = await _db.collection('drivers').doc('rajesh_kumar').get();
      if (!doc.exists) {
        await seedMockDriver();
        return getDriverProfile();
      }
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  // Pre-seed mock driver details if empty
  Future<void> seedMockDriver() async {
    await _db.collection('drivers').doc('rajesh_kumar').set({
      'driverName': 'Rajesh Kumar',
      'driverPhone': '+91 98765 43210',
      'vehicleNo': 'MH-12-AB-1234',
      'vehicleModel': 'Tata Signa 5530.S',
      'avatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop',
      'emergencyName': 'Sunita Kumar',
      'emergencyRelation': 'Wife',
      'emergencyPhone': '+91 98765 54321',
      'name': 'Rajesh Kumar',
      'phone': '+91 98765 43210',
      'relation': 'Wife',
      'licenseNo': 'DL-IND-8829310',
      'licenseClass': 'Heavy Transport (HTV)',
      'licenseExpires': 'Oct 2028',
      'safetyRating': '4.9',
      'kmDriven': '12k+',
      'employer': 'Northway Logistics Ltd.',
      'fleetHub': 'Gurgaon-Sector 45',
      'appVersion': 'v4.2.0 (Build 902)',
      'documents': [
        {
          'title': 'Driving License',
          'subtitle': 'HCV Class Authority',
          'expiryDate': '12 Oct 2026',
          'status': 'Valid',
          'statusMsg': '842 Days Left',
          'icon': 'badge',
        },
        {
          'title': 'National ID Card',
          'subtitle': 'Aadhar Card / PAN',
          'expiryDate': '01 Jan 2024',
          'status': 'Expired',
          'statusMsg': 'Expired',
          'icon': 'contact_mail',
        },
        {
          'title': 'Company ID',
          'subtitle': 'Logistics Corp ID: 9012',
          'expiryDate': 'Indefinite',
          'status': 'Active',
          'statusMsg': 'Authorized',
          'icon': 'business',
        }
      ]
    });
  }

  // Update emergency contact numbers in Firestore
  Future<void> updateEmergencyContact(String name, String relation, String phone) async {
    try {
      await _db.collection('drivers').doc('rajesh_kumar').set({
        'emergencyName': name,
        'emergencyRelation': relation,
        'emergencyPhone': phone,
        'name': name,
        'relation': relation,
        'phone': phone,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Update driver details in Firestore
  Future<void> updateDriverProfile(Map<String, dynamic> data) async {
    try {
      await _db.collection('drivers').doc('rajesh_kumar').set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  // Upload driver avatar photo to Firebase Storage
  Future<String> uploadDriverAvatar(String filePath) async {
    try {
      if (useMockStorage) {
        if (filePath.isNotEmpty && !filePath.startsWith('http') && await File(filePath).exists()) {
          return filePath;
        }
        return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop';
      }
      if (!await File(filePath).exists()) {
        return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop';
      }
      final file = File(filePath);
      final ref = _storage.ref().child('avatars').child('rajesh_kumar.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('------------------------------------------------------------');
      debugPrint('WARNING: Firebase Storage upload failed for Driver Avatar: $e');
      debugPrint('If you see a 404 Not Found error, it means your Firebase Storage bucket has not been initialized.');
      debugPrint('To resolve this, please open the Firebase Console, navigate to "Storage", click "Get Started" and enable the bucket.');
      debugPrint('Falling back to local file path.');
      debugPrint('------------------------------------------------------------');
      return filePath;
    }
  }

  // Update documents lists in Firestore
  Future<void> updateDriverDocuments(List<Map<String, dynamic>> docsList) async {
    try {
      await _db.collection('drivers').doc('rajesh_kumar').set({
        'documents': docsList,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
