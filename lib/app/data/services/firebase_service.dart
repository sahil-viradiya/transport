import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:transport/app/modules/trips/controllers/trips_controller.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:flutter/material.dart';

/// Firestore + Storage data layer.
///
/// Everything a single truck owner sees is scoped to their [ownerKey]
/// (their phone number). Admin-only aggregate reads (getTrips/getUsers/...)
/// remain unscoped and are gated by security rules.
///
/// The Firestore/Storage instances and the owner-key resolver are injectable so
/// the service can be unit-tested with `fake_cloud_firestore`.
class FirebaseService extends GetxService {
  // When true, image uploads return public mock URLs instead of hitting
  // Firebase Storage. Kept false so uploads actually go to Firebase; the
  // upload methods still fall back gracefully if the bucket isn't enabled.
  static const bool useMockStorage = false;

  final FirebaseFirestore _db;
  final FirebaseStorage? _injectedStorage;
  final String Function()? _ownerKeyResolver;

  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    String Function()? ownerKeyResolver,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _injectedStorage = storage,
        _ownerKeyResolver = ownerKeyResolver;

  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  Future<FirebaseService> init() async {
    return this;
  }

  /// The current owner's document key (normalised phone). Resolved from the
  /// injected resolver (tests) or the live [SessionService] (app).
  String get ownerKey {
    final resolver = _ownerKeyResolver;
    if (resolver != null) return resolver();
    try {
      return Get.find<SessionService>().ownerKey;
    } catch (_) {
      return '';
    }
  }

  DocumentReference<Map<String, dynamic>> _ownerDoc([String? key]) {
    final id = (key == null || key.isEmpty) ? ownerKey : key;
    return _db.collection('drivers').doc(id);
  }

  // ---------------------------------------------------------------------------
  // TRIPS
  // ---------------------------------------------------------------------------

  TripItemModel _tripFromDoc(String id, Map<String, dynamic> data) {
    return TripItemModel(
      id: id,
      truckNo: data['truckNo'] ?? '',
      status: data['status'] ?? '',
      pickupCity: data['pickupCity'] ?? '',
      pickupLocation: data['pickupLocation'] ?? '',
      dropCity: data['dropCity'] ?? '',
      dropLocation: data['dropLocation'] ?? '',
      date: data['date'] ?? '',
      tabType: data['tabType'] ?? '',
      isActive: data['isActive'] ?? false,
      currentMilestone: (data['currentMilestone'] as num?)?.toInt() ?? 0,
      remainingDistance: data['remainingDistance'] ?? '',
      estimatedTime: data['estimatedTime'] ?? '',
      currentAddress: data['currentAddress'] ?? '',
      driverPhone: data['driverPhone'] ?? '',
      pickupLatitude: (data['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (data['pickupLongitude'] as num?)?.toDouble(),
      dropLatitude: (data['dropLatitude'] as num?)?.toDouble(),
      dropLongitude: (data['dropLongitude'] as num?)?.toDouble(),
      milestonesLog: data['milestonesLog'],
      podUrl: data['podUrl'],
      remarks: data['remarks'],
    );
  }

  /// Owner-scoped trips. Live UI should prefer [watchTripsForOwner].
  Future<List<TripItemModel>> getTripsForOwner([String? key]) async {
    final owner = (key == null || key.isEmpty) ? ownerKey : key;
    if (owner.isEmpty) return [];
    try {
      final snapshot =
          await _db.collection('trips').where('ownerId', isEqualTo: owner).get();
      return snapshot.docs.map((d) => _tripFromDoc(d.id, d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Real-time owner-scoped trips stream for reactive dashboards.
  Stream<List<TripItemModel>> watchTripsForOwner([String? key]) {
    final owner = (key == null || key.isEmpty) ? ownerKey : key;
    if (owner.isEmpty) return Stream.value(<TripItemModel>[]);
    return _db
        .collection('trips')
        .where('ownerId', isEqualTo: owner)
        .snapshots()
        .map((s) => s.docs.map((d) => _tripFromDoc(d.id, d.data())).toList());
  }

  /// Unscoped: all trips. Admin only — gated by security rules.
  Future<List<TripItemModel>> getTrips() async {
    try {
      final snapshot = await _db.collection('trips').get();
      return snapshot.docs.map((d) => _tripFromDoc(d.id, d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Live stream of all trips for the admin operations dashboard, so milestone
  /// progress and last-known locations update without a manual refresh.
  Stream<List<TripItemModel>> watchAllTrips() {
    return _db.collection('trips').snapshots().map(
        (s) => s.docs.map((d) => _tripFromDoc(d.id, d.data())).toList());
  }

  Future<Map<String, dynamic>?> getTripData(String tripId) async {
    try {
      final doc = await _db.collection('trips').doc(tripId).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Stream<Map<String, dynamic>?> watchTripData(String tripId) {
    return _db.collection('trips').doc(tripId).snapshots().map((d) => d.data());
  }

  Future<void> saveTrip(String tripId, Map<String, dynamic> tripData) async {
    try {
      // A trip belongs to the driver it is assigned to, so its `ownerId` (what
      // the driver's owner-scoped query matches on) must be the driver's phone.
      // When an admin assigns a trip, derive ownerId from driverPhone — NOT from
      // the admin who is currently signed in. Phones are normalised so they
      // match the driver's session key exactly. Falls back to the current owner
      // for the owner-operator self-create case.
      final assigned = tripData['driverPhone']?.toString().trim() ?? '';
      if (assigned.isNotEmpty) {
        final normalized = SessionService.normalizePhone(assigned);
        tripData['driverPhone'] = normalized;
        tripData['ownerId'] = normalized;
      } else {
        tripData.putIfAbsent('ownerId', () => ownerKey);
      }
      await _db
          .collection('trips')
          .doc(tripId)
          .set(tripData, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      await _db.collection('trips').doc(tripId).delete();
    } catch (_) {}
  }

  /// Update trip milestones & status, appending to the immutable milestone log.
  Future<void> updateTripMilestone(
    String tripId,
    int milestone, {
    String? status,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      if (status == 'ACTIVE NOW') {
        // Only one trip can be active at a time for this owner.
        final owner = ownerKey;
        Query<Map<String, dynamic>> q =
            _db.collection('trips').where('isActive', isEqualTo: true);
        if (owner.isNotEmpty) q = q.where('ownerId', isEqualTo: owner);
        final activeSnapshot = await q.get();
        for (final doc in activeSnapshot.docs) {
          if (doc.id != tripId) {
            await doc.reference.set(
              {'status': 'ASSIGNED', 'isActive': false},
              SetOptions(merge: true),
            );
          }
        }
      }

      final updates = <String, dynamic>{'currentMilestone': milestone};
      if (status != null) {
        updates['status'] = status;
        if (status == 'ACTIVE NOW') {
          updates['isActive'] = true;
        } else if (status == 'DELIVERED') {
          updates['isActive'] = false;
        }
      }

      const labels = {
        0: 'Created',
        1: 'Trip Assigned',
        2: 'Reached Pickup',
        3: 'Loaded',
        4: 'Reached Drop / Delivered',
      };

      final logEntry = {
        'milestone': milestone,
        'label': labels[milestone] ?? 'Updated',
        'timestamp':
            DateTime.now().toIso8601String().split('T').join(' ').substring(0, 16),
        'address': locationName ?? 'Terminal Gate',
        'latitude': latitude ?? 0.0,
        'longitude': longitude ?? 0.0,
      };
      updates['milestonesLog'] = FieldValue.arrayUnion([logEntry]);

      await _db
          .collection('trips')
          .doc(tripId)
          .set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

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
      if (remainingDistance != null) updates['remainingDistance'] = remainingDistance;
      if (estimatedTime != null) updates['estimatedTime'] = estimatedTime;
      await _db
          .collection('trips')
          .doc(tripId)
          .set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // PROOF OF DELIVERY
  // ---------------------------------------------------------------------------

  Future<String> uploadProofOfDelivery(String tripId, String filePath) async {
    final owner = ownerKey.isEmpty ? 'unknown' : ownerKey;
    try {
      if (useMockStorage) {
        if (filePath.isNotEmpty &&
            !filePath.startsWith('http') &&
            await File(filePath).exists()) {
          return filePath;
        }
        return 'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=600';
      }
      if (filePath.isEmpty || !await File(filePath).exists()) {
        return filePath;
      }
      final ref = _storage
          .ref()
          .child('proof_of_delivery')
          .child(owner)
          .child('$tripId.jpg');
      final uploadTask = await ref.putFile(File(filePath));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Proof of Delivery', e);
      return filePath;
    }
  }

  Future<void> saveProofOfDeliveryDetails(
    String tripId,
    String downloadUrl,
    String remarks, {
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await updateTripMilestone(
        tripId,
        4,
        status: 'DELIVERED',
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
      );
      await _db.collection('trips').doc(tripId).set(
        {'podUrl': downloadUrl, 'remarks': remarks},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // OWNER / DRIVER PROFILE  (scoped to drivers/{ownerKey})
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getDriverProfile([String? key]) async {
    try {
      final doc = await _ownerDoc(key).get();
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  Stream<Map<String, dynamic>> watchDriverProfile([String? key]) {
    return _ownerDoc(key).snapshots().map((d) => d.data() ?? {});
  }

  Future<void> updateDriverProfile(Map<String, dynamic> data, [String? key]) async {
    try {
      await _ownerDoc(key).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateDriverLocation(
      double latitude, double longitude, String address,
      [String? key]) async {
    try {
      await _ownerDoc(key).set({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'currentAddress': address,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateEmergencyContact(
      String name, String relation, String phone,
      [String? key]) async {
    try {
      await _ownerDoc(key).set({
        'emergencyName': name,
        'emergencyRelation': relation,
        'emergencyPhone': phone,
        'name': name,
        'relation': relation,
        'phone': phone,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateDriverDocuments(List<Map<String, dynamic>> docsList,
      [String? key]) async {
    try {
      await _ownerDoc(key).set({'documents': docsList}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<String> uploadDriverAvatar(String filePath, [String? key]) async {
    final owner = (key == null || key.isEmpty) ? ownerKey : key;
    try {
      if (useMockStorage) {
        if (filePath.isNotEmpty &&
            !filePath.startsWith('http') &&
            await File(filePath).exists()) {
          return filePath;
        }
        return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop';
      }
      if (filePath.isEmpty || !await File(filePath).exists()) {
        return filePath;
      }
      final ref = _storage
          .ref()
          .child('avatars')
          .child('${owner.isEmpty ? 'unknown' : owner}.jpg');
      final uploadTask = await ref.putFile(File(filePath));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Driver Avatar', e);
      return filePath;
    }
  }

  // ---------------------------------------------------------------------------
  // USERS  (login directory, keyed by phone)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final snapshot = await _db.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['phone'] = doc.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserData(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) data['phone'] = doc.id;
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(String phone, Map<String, dynamic> userData) async {
    try {
      await _db.collection('users').doc(phone).set(userData, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateUserRole(String phone, String newRole) async {
    try {
      await _db.collection('users').doc(phone).set({'role': newRole}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> deleteUser(String phone) async {
    try {
      await _db.collection('users').doc(phone).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // TRUCKS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getTrucks() async {
    try {
      final snapshot = await _db.collection('trucks').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrucksForOwner([String? key]) async {
    final owner = (key == null || key.isEmpty) ? ownerKey : key;
    if (owner.isEmpty) return [];
    try {
      final snapshot =
          await _db.collection('trucks').where('ownerId', isEqualTo: owner).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTruck(String truckId, Map<String, dynamic> truckData) async {
    try {
      truckData.putIfAbsent('ownerId', () => ownerKey);
      await _db.collection('trucks').doc(truckId).set(truckData, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> deleteTruck(String truckId) async {
    try {
      await _db.collection('trucks').doc(truckId).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final snapshot = await _db.collection('expenses').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Live stream of all expense claims for the admin dashboard.
  Stream<List<Map<String, dynamic>>> watchAllExpenses() {
    return _db.collection('expenses').snapshots().map((s) => s.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList());
  }

  Future<List<Map<String, dynamic>>> getExpensesForDriver(String phone) async {
    try {
      final snapshot = await _db
          .collection('expenses')
          .where('driverPhone', isEqualTo: SessionService.normalizePhone(phone))
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExpensesForTrip(String tripId) async {
    try {
      final snapshot =
          await _db.collection('expenses').where('tripId', isEqualTo: tripId).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveExpense(Map<String, dynamic> expenseData) async {
    try {
      expenseData.putIfAbsent('ownerId', () => ownerKey);
      final id =
          expenseData['id'] ?? 'EXP-${DateTime.now().millisecondsSinceEpoch}';
      await _db.collection('expenses').doc(id).set(expenseData, SetOptions(merge: true));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // OWNER ONBOARDING / DEMO SEED
  // ---------------------------------------------------------------------------

  /// Seeds a brand-new owner with a starter profile + a little demo data so the
  /// app isn't empty on first launch. Runs once per owner (guarded by the
  /// `seededDemo` flag on their profile). All data is tagged with `ownerId` so
  /// it stays private to this owner.
  Future<void> seedDemoDataForOwner(
    String ownerPhone, {
    required String name,
    String? avatarUrl,
  }) async {
    final owner = SessionService.normalizePhone(ownerPhone);
    if (owner.isEmpty) return;
    try {
      final profileRef = _ownerDoc(owner);
      final existing = await profileRef.get();
      if (existing.exists && (existing.data()?['seededDemo'] == true)) {
        return; // already seeded
      }

      // 1. Owner profile
      await profileRef.set({
        'driverName': name,
        'driverPhone': ownerPhone,
        'name': name,
        'phone': ownerPhone,
        'avatarUrl': avatarUrl ?? '',
        'vehicleNo': 'GJ-01-AB-1234',
        'vehicleModel': 'Tata Signa 5530.S',
        'licenseNo': '',
        'licenseClass': 'Heavy Transport (HTV)',
        'role': 'owner',
        'seededDemo': true,
        'documents': [
          {
            'title': 'Vehicle RC',
            'subtitle': 'Registration Certificate',
            'expiryDate': 'Indefinite',
            'status': 'Active',
            'statusMsg': 'Valid',
            'icon': 'business',
          },
          {
            'title': 'Driving License',
            'subtitle': 'HCV Class Authority',
            'expiryDate': '12 Oct 2028',
            'status': 'Valid',
            'statusMsg': 'Valid',
            'icon': 'badge',
          },
        ],
      }, SetOptions(merge: true));

      // 2. A truck owned by this owner
      await _db.collection('trucks').doc('${owner}_GJ-01-AB-1234').set({
        'truckNo': 'GJ-01-AB-1234',
        'model': 'Tata Signa 5530.S',
        'status': 'Idle',
        'ownerId': owner,
      }, SetOptions(merge: true));

      // 3. A couple of demo trips owned by this owner
      final demoTrips = <Map<String, dynamic>>[
        {
          'truckNo': 'GJ-01-AB-1234',
          'status': 'ASSIGNED',
          'pickupCity': 'Ahmedabad',
          'pickupLocation': 'Aslali Transport Nagar',
          'dropCity': 'Mumbai',
          'dropLocation': 'Bhiwandi Godown',
          'date': 'Today, 09:00 AM',
          'tabType': 'Today',
          'isActive': false,
          'currentMilestone': 1,
          'driverPhone': owner,
          'ownerId': owner,
        },
        {
          'truckNo': 'GJ-01-AB-1234',
          'status': 'ASSIGNED',
          'pickupCity': 'Surat',
          'pickupLocation': 'Sachin GIDC',
          'dropCity': 'Indore',
          'dropLocation': 'Pithampur Hub',
          'date': 'Tomorrow, 06:00 AM',
          'tabType': 'Upcoming',
          'isActive': false,
          'currentMilestone': 0,
          'driverPhone': owner,
          'ownerId': owner,
        },
      ];
      for (var i = 0; i < demoTrips.length; i++) {
        await _db
            .collection('trips')
            .doc('${owner}_DEMO_$i')
            .set(demoTrips[i], SetOptions(merge: true));
      }

      // 4. A demo expense
      await _db.collection('expenses').doc('${owner}_EXP_0').set({
        'tripId': '${owner}_DEMO_0',
        'driverPhone': owner,
        'ownerId': owner,
        'title': 'Diesel Fill',
        'description': 'IOCL Pump • Aslali',
        'amount': '₹8,500',
        'date': 'Today, 09:30 AM',
        'status': 'Approved',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _warnStorage(String what, Object e) {
    debugPrint('------------------------------------------------------------');
    debugPrint('WARNING: Firebase Storage upload failed for $what: $e');
    debugPrint('If you see a 404, your Firebase Storage bucket is not enabled.');
    debugPrint('Open Firebase Console > Storage > Get Started to enable it.');
    debugPrint('Falling back to the local file path for now.');
    debugPrint('------------------------------------------------------------');
  }
}
