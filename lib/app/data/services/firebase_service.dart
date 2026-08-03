import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:transport/app/modules/trips/controllers/trips_controller.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transport/app/core/config/app_config.dart';
import 'package:transport/app/core/utils/app_logger.dart';

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
  // Firebase Storage. Dynamically connected to global AppConfig.
  static bool get useMockStorage => AppConfig.isMock;

  final FirebaseFirestore _db;
  final FirebaseStorage? _injectedStorage;
  final String Function()? _ownerKeyResolver;

  bool _phoneKeysMigrated = false;

  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    String Function()? ownerKeyResolver,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _injectedStorage = storage,
        _ownerKeyResolver = ownerKeyResolver;

  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  Future<FirebaseService> init() async {
    // Native clients already persist Firestore data by default. The web SDK
    // defaults to memory-only caching, so enable its disk cache when possible.
    // A shared browser profile can reject persistence; live reads still work.
    if (_injectedStorage == null && kIsWeb) {
      try {
        _db.settings = const Settings(persistenceEnabled: true);
      } catch (_) {}
    }
    return this;
  }

  /// Commits independent updates in Firestore's maximum-size-safe chunks.
  /// This preserves each document's payload while replacing N network commits
  /// with one commit per 500 documents.
  Future<void> _setInBatches(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
    Map<String, dynamic> data,
  ) async {
    final refs = references.toList(growable: false);
    for (var start = 0; start < refs.length; start += 500) {
      final batch = _db.batch();
      for (final ref in refs.skip(start).take(500)) {
        batch.set(ref, data, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// Runs a Firestore write and turns a failure into a readable error instead
  /// of swallowing it.
  ///
  /// Writes used to be wrapped in `catch (_) {}`, so a rejected write (most
  /// often `permission-denied` from security rules that aren't deployed, or an
  /// expired test-mode rule) looked like success: the row simply never
  /// appeared, with no error anywhere. Callers already show an error snackbar —
  /// they just never received one. Now they do.
  Future<T> _write<T>(String action, Future<T> Function() op) async {
    try {
      return await op();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            '$action: Firestore ne permission deny kiya (permission-denied). '
            'Rules deploy karein: firebase deploy --only firestore:rules');
      }
      if (e.code == 'unavailable') {
        throw Exception(
            '$action: Firestore reachable nahi hai — internet check karein.');
      }
      throw Exception('$action: ${e.message ?? e.code}');
    }
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
      priority: data['priority'] ?? false,
      currentMilestone: (data['currentMilestone'] as num?)?.toInt() ?? 0,
      vendorName: data['vendorName'] ?? '',
      vendorLocation: data['vendorLocation'] ?? '',
      materialName: data['materialName'] ?? '',
      productName: data['productName'] ?? '',
      passHolderName: data['passHolderName'] ?? '',
      royaltyName: data['royaltyName'] ?? '',
      loadingPassId: data['loadingPassId'] ?? '',
      minPassId: data['minPassId'] ?? '',
      maxPassId: data['maxPassId'] ?? '',
      pickupDistrict: data['pickupDistrict'] ?? '',
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
      loadingPhotoUrl: data['loadingPhotoUrl'],
      gatePassPhotoUrl: data['gatePassPhotoUrl'],
      loadingPassGeneratedAt: data['loadingPassGeneratedAt'] ?? '',
      loadRejectCount: (data['loadRejectCount'] as num?)?.toInt() ?? 0,
      loadRejectReason: data['loadRejectReason'] ?? '',
      flaggedPhoto: data['flaggedPhoto'] ?? 'both',
      loadRejectAudit: data['loadRejectAudit'],
      needsSupervisor: data['needsSupervisor'] ?? false,
      deliveryRejectCount: (data['deliveryRejectCount'] as num?)?.toInt() ?? 0,
      deliveryRejectReason: data['deliveryRejectReason'] ?? '',
      deliveryRejectAudit: data['deliveryRejectAudit'],
      hasTruckOwnerPass: data['hasTruckOwnerPass'] ?? false,
      truckOwnerPassId: data['truckOwnerPassId'] ?? '',
      truckOwnerPassUrl: data['truckOwnerPassUrl'] ?? '',
      truckOwnerPassData: data['truckOwnerPassData'] as Map<String, dynamic>?,
    );
  }

  /// Owner-scoped trips. Live UI should prefer [watchTripsForOwner].
  Future<List<TripItemModel>> getTripsForOwner([String? key]) async {
    final owner = (key == null || key.isEmpty) ? ownerKey : key;
    if (owner.isEmpty) return [];
    try {
      final snapshot = await _db
          .collection('trips')
          .where('ownerId', isEqualTo: owner)
          .get();
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
    return _db
        .collection('trips')
        .snapshots()
        .map((s) => s.docs.map((d) => _tripFromDoc(d.id, d.data())).toList());
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
      final actingUser = ownerKey; // who is signed in (admin or owner)
      final assigned = tripData['driverPhone']?.toString().trim() ?? '';
      if (assigned.isNotEmpty) {
        final normalized = SessionService.normalizePhone(assigned);
        tripData['driverPhone'] = normalized;
        tripData['ownerId'] = normalized;
      } else {
        tripData.putIfAbsent('ownerId', () => ownerKey);
      }
      // Remember who assigned the trip so the driver's accept/reject can notify
      // them back.
      if (actingUser.isNotEmpty) {
        tripData.putIfAbsent('assignedBy', () => actingUser);
      }
      await _write(
          'Trip save nahi hua',
          () => _db
              .collection('trips')
              .doc(tripId)
              .set(tripData, SetOptions(merge: true)));
    } on FirebaseException catch (e) {
      throw Exception('Trip save nahi hua: ${e.message ?? e.code}');
    }
  }

  // ---------------------------------------------------------------------------
  // TRIP CONFIRMATION LIFECYCLE
  // Statuses: PENDING (awaiting driver) -> ASSIGNED (accepted, ready to start)
  //           -> ACTIVE NOW -> DELIVERED.  REJECTED = driver declined.
  // ---------------------------------------------------------------------------

  /// Driver accepts a PENDING trip. It becomes ASSIGNED (ready to start) and the
  /// admin who assigned it is notified.
  Future<void> acceptTrip(String tripId, {String? driverName}) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      if (data['status'] != 'PENDING') return; // already handled
      await _db.collection('trips').doc(tripId).set({
        'status': 'ASSIGNED',
        'confirmedByDriver': true,
        'confirmedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Trip Confirmed ✅',
          body: '${driverName ?? 'Driver'} confirmed trip $tripId.',
          type: 'trip_accepted',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  /// Driver rejects a PENDING trip. The admin is notified so they can reassign.
  Future<void> rejectTrip(String tripId,
      {String reason = '', String? driverName}) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      if (data['status'] != 'PENDING') return; // already handled
      await _db.collection('trips').doc(tripId).set({
        'status': 'REJECTED',
        'confirmedByDriver': false,
        'rejectReason': reason,
      }, SetOptions(merge: true));

      final truckNo = data['truckNo']?.toString() ?? '';
      if (truckNo.isNotEmpty) {
        await _db.collection('trucks').doc(truckNo).update({
          'loadingPass': FieldValue.delete(),
          'hasLoadingPass': FieldValue.delete(),
          'destinationSetup': FieldValue.delete(),
          'hasDestinationSetup': FieldValue.delete(),
        });
      }

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Trip Rejected ❌',
          body: '${driverName ?? 'Driver'} rejected trip $tripId.'
              '${reason.isNotEmpty ? ' Reason: $reason' : ''}',
          type: 'trip_rejected',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  /// Admin assigns/creates a trip for a driver: writes it as PENDING and pings
  /// the driver to accept or reject.
  Future<void> assignTripToDriver(
      String tripId, Map<String, dynamic> tripData) async {
    tripData['status'] = 'PENDING';
    tripData['confirmedByDriver'] = false;
    await saveTrip(tripId, tripData);
    final driverPhone = tripData['driverPhone']?.toString() ?? '';
    if (driverPhone.isNotEmpty) {
      await createNotification(
        toPhone: driverPhone,
        title: 'New Trip Assigned 🚚',
        body: 'Trip $tripId: ${tripData['pickupCity'] ?? ''} → '
            '${tripData['dropCity'] ?? ''}. Accept or reject it.',
        type: 'trip_assigned',
        tripId: tripId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD APPROVAL GATE
  // A trip does NOT go active on its own. The driver reaches pickup, loads the
  // goods, then requests approval. Admin approves -> ACTIVE NOW.
  // Statuses here: ASSIGNED -> LOAD_REQUESTED -> ACTIVE NOW.
  // ---------------------------------------------------------------------------

  /// Driver accepted the trip and is leaving for the vendor to collect the
  /// material — admin sees "on the way" and gets pinged.
  Future<void> startToVendor(
    String tripId, {
    String? location,
    double? latitude,
    double? longitude,
    String? driverName,
  }) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      if (data['status'] != 'ASSIGNED') return; // wrong stage
      await _db.collection('trips').doc(tripId).set({
        'status': 'EN_ROUTE_VENDOR',
        'milestonesLog': FieldValue.arrayUnion([
          {
            'milestone': 1,
            'label': 'En Route to Vendor (On The Way)',
            'timestamp': DateTime.now()
                .toIso8601String()
                .split('T')
                .join(' ')
                .substring(0, 16),
            'address': location ?? data['vendorLocation'] ?? '',
            'latitude': latitude ?? 0.0,
            'longitude': longitude ?? 0.0,
          }
        ]),
      }, SetOptions(merge: true));

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Driver On The Way 🛻',
          body: '${driverName ?? 'Driver'} vendor '
              '${(data['vendorName'] ?? '').toString().isNotEmpty ? '${data['vendorName']} ' : ''}'
              'ke paas material lene nikla hai (trip $tripId).',
          type: 'vendor_way',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  /// Driver reached the vendor, showed the loading pass, and loading has
  /// started. Admin is pinged to set the destination NOW (it stays hidden from
  /// the driver until the load is approved).
  Future<void> startLoading(
    String tripId, {
    String? location,
    double? latitude,
    double? longitude,
    String? driverName,
  }) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      final st = data['status'];
      if (st != 'EN_ROUTE_VENDOR' && st != 'ASSIGNED') return;
      await _db.collection('trips').doc(tripId).set({
        'status': 'LOADING',
        'currentMilestone': 2,
        'loadingStartedAt': FieldValue.serverTimestamp(),
        'milestonesLog': FieldValue.arrayUnion([
          {
            'milestone': 2,
            'label': 'Reached Vendor — Loading Started',
            'timestamp': DateTime.now()
                .toIso8601String()
                .split('T')
                .join(' ')
                .substring(0, 16),
            'address': location ?? data['vendorLocation'] ?? '',
            'latitude': latitude ?? 0.0,
            'longitude': longitude ?? 0.0,
          }
        ]),
      }, SetOptions(merge: true));

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Truck Loading 📦',
          body: '${driverName ?? 'Driver'} ka truck load ho raha hai '
              '(trip $tripId). Abhi destination set kar dein.',
          type: 'loading_started',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  /// Admin sets the drop destination (during loading). The driver only sees it
  /// once the load is approved and the trip goes ACTIVE.
  Future<void> setTripDestination(
    String tripId, {
    required String dropCity,
    required String dropLocation,
    String customerName = '',
    String customerAddress = '',
    double? dropLatitude,
    double? dropLongitude,
  }) async {
    try {
      await _db.collection('trips').doc(tripId).set({
        'dropCity': dropCity,
        'dropLocation': dropLocation,
        if (customerName.isNotEmpty) 'customerName': customerName,
        if (customerAddress.isNotEmpty) 'customerAddress': customerAddress,
        if (dropLatitude != null) 'dropLatitude': dropLatitude,
        if (dropLongitude != null) 'dropLongitude': dropLongitude,
        'destinationSetAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// One-time reminder to the admin when the destination still isn't set
  /// ~10 minutes after the load request. Returns true if a reminder was sent.
  Future<bool> remindSetDestination(String tripId) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      if (data['status'] != 'LOAD_REQUESTED' && data['status'] != 'LOADING')
        return false;
      if (data['destinationReminderSent'] == true) return false;
      if ((data['dropCity'] ?? '').toString().isNotEmpty) return false;

      await _db
          .collection('trips')
          .doc(tripId)
          .set({'destinationReminderSent': true}, SetOptions(merge: true));

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Reminder: Destination Set Karein ⏰',
          body:
              'Trip $tripId ka truck loaded/loading status me hai aur 10 minute ho gaye — '
              'destination set karein.',
          type: 'set_destination_reminder',
          tripId: tripId,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Upload a loading-proof photo taken at the vendor site.
  Future<String> uploadLoadingPhoto(String tripId, Uint8List? bytes) async {
    final owner = ownerKey.isEmpty ? 'unknown' : ownerKey;
    const placeholder =
        'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=600';
    if (bytes == null || bytes.isEmpty || useMockStorage) return placeholder;
    try {
      final ref = _storage
          .ref()
          .child('loading_photos')
          .child(owner)
          .child('$tripId.jpg');
      final task =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Loading Photo', e);
      throw Exception('Loading Photo upload failed: $e');
    }
  }

  /// Upload a gate pass photo taken at the vendor site.
  Future<String> uploadGatePassPhoto(String tripId, Uint8List? bytes) async {
    final owner = ownerKey.isEmpty ? 'unknown' : ownerKey;
    const placeholder =
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=600';
    if (bytes == null || bytes.isEmpty || useMockStorage) return placeholder;
    try {
      final ref = _storage
          .ref()
          .child('gate_pass_photos')
          .child(owner)
          .child('$tripId.jpg');
      final task =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Gate Pass Photo', e);
      throw Exception('Gate Pass Photo upload failed: $e');
    }
  }

  /// Driver has loaded goods at pickup and asks the admin to activate the trip.
  /// The trip is marked `LOAD_REQUESTED` (still not active) and the admin is
  /// notified with an approve/reject request.
  Future<void> requestLoadApproval(
    String tripId, {
    String? pickupLocation,
    String? driverName,
    double? latitude,
    double? longitude,
    String? loadingPhotoUrl,
    String? gatePassPhotoUrl,
  }) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      await _db.collection('trips').doc(tripId).set({
        'status': 'LOAD_REQUESTED',
        'currentMilestone': 3,
        'isActive': false,
        'loadRequestedAt': FieldValue.serverTimestamp(),
        'loadRejectReason': '',
        if (loadingPhotoUrl != null && loadingPhotoUrl.isNotEmpty)
          'loadingPhotoUrl': loadingPhotoUrl,
        if (gatePassPhotoUrl != null && gatePassPhotoUrl.isNotEmpty)
          'gatePassPhotoUrl': gatePassPhotoUrl,
        if (latitude != null) 'pickupLatitude': latitude,
        if (longitude != null) 'pickupLongitude': longitude,
        if (pickupLocation != null) 'pickupLocation': pickupLocation,
        'milestonesLog': FieldValue.arrayUnion([
          {
            'milestone': 3,
            'label': 'Cargo Loaded — Awaiting Admin Approval',
            'timestamp': DateTime.now()
                .toIso8601String()
                .split('T')
                .join(' ')
                .substring(0, 16),
            'address': pickupLocation ?? data['pickupLocation'] ?? '',
            'latitude': latitude ?? 0.0,
            'longitude': longitude ?? 0.0,
          }
        ]),
      }, SetOptions(merge: true));

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Load Approval Needed 📦',
          body:
              '${driverName ?? 'Driver'} loaded goods${(pickupLocation ?? data['pickupLocation'] ?? '').toString().isNotEmpty ? ' at ${pickupLocation ?? data['pickupLocation']}' : ''} for trip $tripId. Approve to activate.',
          type: 'load_request',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  /// Admin approves the load — the trip becomes ACTIVE NOW (and any other active
  /// trip of that driver is suspended). The driver is notified and only now
  /// sees the destination. Returns an error message when it can't be approved
  /// (already handled, or destination not set yet), null on success.
  Future<String?> approveLoad(
    String tripId, {
    String? adminName,
    String? truckOwnerPassId,
    String? truckOwnerPassUrl,
    Map<String, dynamic>? truckOwnerPassData,
  }) async {
    try {
      final docRef = _db.collection('trips').doc(tripId);
      final data = (await docRef.get()).data() ?? {};
      if (data['status'] != 'LOAD_REQUESTED') {
        return 'Ye request pehle hi handle ho chuki hai.';
      }
      if ((data['dropCity'] ?? '').toString().trim().isEmpty &&
          (data['dropLocation'] ?? '').toString().trim().isEmpty) {
        return 'Pehle destination set karein — uske bina load approve nahi '
            'ho sakta.';
      }
      await docRef.set({
        'hasTruckOwnerPass': true,
        if (truckOwnerPassId != null && truckOwnerPassId.isNotEmpty)
          'truckOwnerPassId': truckOwnerPassId,
        if (truckOwnerPassUrl != null && truckOwnerPassUrl.isNotEmpty)
          'truckOwnerPassUrl': truckOwnerPassUrl,
        if (truckOwnerPassData != null)
          'truckOwnerPassData': truckOwnerPassData,
      }, SetOptions(merge: true));

      await updateTripMilestone(
        tripId,
        3,
        status: 'ACTIVE NOW',
        locationName:
            (data['pickupLocation'] ?? 'Approved by admin').toString(),
        latitude: (data['pickupLatitude'] as num?)?.toDouble(),
        longitude: (data['pickupLongitude'] as num?)?.toDouble(),
      );
      final driverPhone =
          (data['driverPhone'] ?? data['ownerId'])?.toString() ?? '';
      if (driverPhone.isNotEmpty) {
        await createNotification(
          toPhone: driverPhone,
          title: 'Trip Activated ✅',
          body:
              'Admin approved your load and issued Truck Owner Pass. Trip $tripId is now ACTIVE — '
              'destination: ${data['dropCity'] ?? ''} '
              '${data['dropLocation'] ?? ''}. Drive safely!',
          type: 'trip_activated',
          tripId: tripId,
        );
      }
      return null;
    } catch (e) {
      return 'Approve nahi ho paya: $e';
    }
  }

  /// Admin rejects the load — the trip goes back to LOAD_REJECTED and the driver is
  /// told why.
  Future<void> rejectLoad(String tripId,
      {String reason = '',
      String flaggedPhoto = 'both',
      String? adminName}) async {
    try {
      final docRef = _db.collection('trips').doc(tripId);
      final data = (await docRef.get()).data() ?? {};
      if (data['status'] != 'LOAD_REQUESTED') return; // already handled

      final currentRejectCount =
          (data['loadRejectCount'] as num?)?.toInt() ?? 0;
      final newRejectCount = currentRejectCount + 1;
      final needsEscalation = newRejectCount >= 3;

      final auditEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason,
        'flaggedPhoto': flaggedPhoto,
        'adminName': adminName ?? 'Admin',
        'rejectCount': newRejectCount,
      };

      await docRef.set({
        'status': 'LOAD_REJECTED',
        'loadRejectReason': reason,
        'flaggedPhoto': flaggedPhoto,
        'loadRejectCount': newRejectCount,
        'needsSupervisor': needsEscalation,
        'loadRejectAudit': FieldValue.arrayUnion([auditEntry]),
      }, SetOptions(merge: true));

      final driverPhone =
          (data['driverPhone'] ?? data['ownerId'])?.toString() ?? '';
      if (driverPhone.isNotEmpty) {
        await createNotification(
          toPhone: driverPhone,
          title: 'Load Rejected - Reupload Required ⚠️',
          body:
              'Admin rejected loading photos. Reason: $reason. Please reupload.',
          type: 'load_rejected',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // DELIVERY APPROVAL GATE
  // Driver reaches the drop and marks delivered -> admin gets live location +
  // time + notification -> admin approves -> DELIVERED.
  // ---------------------------------------------------------------------------

  /// Driver reached the drop with the goods and marks delivered. Captures live
  /// location + time and asks the admin to approve completion. Trip stays
  /// ACTIVE (status DELIVERY_REQUESTED) until the admin approves.
  Future<void> requestDelivery(
    String tripId, {
    String? location,
    double? latitude,
    double? longitude,
    String? driverName,
  }) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      final now = DateTime.now()
          .toIso8601String()
          .split('T')
          .join(' ')
          .substring(0, 16);
      await _db.collection('trips').doc(tripId).set({
        'status': 'DELIVERY_REQUESTED',
        'deliveryRequestedAt': FieldValue.serverTimestamp(),
        'deliveryRejectReason': '',
        if (latitude != null) 'currentLatitude': latitude,
        if (longitude != null) 'currentLongitude': longitude,
        if (location != null) 'currentAddress': location,
        'milestonesLog': FieldValue.arrayUnion([
          {
            'milestone': 4,
            'label': 'Reached Destination — Awaiting Delivery Approval',
            'timestamp': now,
            'address': (location != null && location.isNotEmpty)
                ? location
                : ((data['dropLocation']?.toString().isNotEmpty == true)
                    ? data['dropLocation'].toString()
                    : ((data['dropCity']?.toString().isNotEmpty == true)
                        ? data['dropCity'].toString()
                        : 'Destination Terminal')),
            'latitude': latitude ?? (data['dropLatitude'] as num?)?.toDouble() ?? 0.0,
            'longitude': longitude ?? (data['dropLongitude'] as num?)?.toDouble() ?? 0.0,
          }
        ]),
      }, SetOptions(merge: true));

      final assignedBy = data['assignedBy']?.toString() ?? '';
      if (assignedBy.isNotEmpty) {
        await createNotification(
          toPhone: assignedBy,
          title: 'Delivery Approval Needed 📍',
          body: '${driverName ?? 'Driver'} reached the drop for trip $tripId'
              '${(location ?? '').toString().isNotEmpty ? ' at $location' : ''}'
              ' • $now. Approve to complete.',
          type: 'delivery_request',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  /// Admin approves the delivery — trip is marked DELIVERED. Driver is notified.
  Future<void> approveDelivery(String tripId, {String? adminName}) async {
    try {
      final data =
          (await _db.collection('trips').doc(tripId).get()).data() ?? {};
      if (data['status'] != 'DELIVERY_REQUESTED') return; // already handled
      await updateTripMilestone(
        tripId,
        4,
        status: 'DELIVERED',
        locationName: (data['currentAddress'] ?? data['dropLocation'] ?? data['dropCity'] ?? 'Destination Terminal').toString(),
        latitude: (data['currentLatitude'] ?? data['dropLatitude'] as num?)?.toDouble(),
        longitude: (data['currentLongitude'] ?? data['dropLongitude'] as num?)?.toDouble(),
      );
      final driverPhone =
          (data['driverPhone'] ?? data['ownerId'])?.toString() ?? '';
      if (driverPhone.isNotEmpty) {
        await createNotification(
          toPhone: driverPhone,
          title: 'Delivery Approved ✅',
          body: 'Trip $tripId is complete. Great job!',
          type: 'delivery_approved',
          tripId: tripId,
        );
      }
      final truckNo = (data['truckNo'] ?? '').toString();
      if (truckNo.isNotEmpty) {
        await _db.collection('trucks').doc(truckNo).update({
          'loadingPass': FieldValue.delete(),
          'hasLoadingPass': FieldValue.delete(),
          'destinationSetup': FieldValue.delete(),
          'hasDestinationSetup': FieldValue.delete(),
        });
      }
    } catch (_) {}
  }

  /// Admin rejects the delivery — trip goes to DELIVERY_REJECTED.
  Future<void> rejectDelivery(String tripId,
      {String reason = '', String? adminName}) async {
    try {
      final docRef = _db.collection('trips').doc(tripId);
      final data = (await docRef.get()).data() ?? {};
      if (data['status'] != 'DELIVERY_REQUESTED') return; // already handled

      final currentRejectCount =
          (data['deliveryRejectCount'] as num?)?.toInt() ?? 0;
      final newRejectCount = currentRejectCount + 1;

      final auditEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason,
        'adminName': adminName ?? 'Admin',
        'rejectCount': newRejectCount,
      };

      await docRef.set({
        'status': 'DELIVERY_REJECTED',
        'deliveryRejectReason': reason,
        'deliveryRejectCount': newRejectCount,
        'deliveryRejectAudit': FieldValue.arrayUnion([auditEntry]),
      }, SetOptions(merge: true));

      final driverPhone =
          (data['driverPhone'] ?? data['ownerId'])?.toString() ?? '';
      if (driverPhone.isNotEmpty) {
        await createNotification(
          toPhone: driverPhone,
          title: 'Delivery Proof Rejected ⚠️',
          body: 'Admin rejected delivery proof for trip $tripId.'
              '${reason.isNotEmpty ? ' Reason: $reason' : ''}',
          type: 'delivery_rejected',
          tripId: tripId,
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // TRIP EXPENSES WITH PROOF + APPROVAL
  // ---------------------------------------------------------------------------

  Future<String> uploadExpenseReceipt(
      String expenseId, Uint8List? bytes) async {
    final owner = ownerKey.isEmpty ? 'unknown' : ownerKey;
    const placeholder =
        'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=600';
    if (bytes == null || bytes.isEmpty || useMockStorage) return placeholder;
    try {
      final ref = _storage
          .ref()
          .child('expense_receipts')
          .child(owner)
          .child('$expenseId.jpg');
      final uploadTask =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Expense Receipt', e);
      throw Exception('Expense Receipt upload failed: $e');
    }
  }

  /// Driver submits a trip expense (fuel, puncture, toll, etc.) with a receipt
  /// proof. Saved as `Pending`; every admin is notified to approve/reject.
  Future<void> submitTripExpense(
    Map<String, dynamic> expenseData, {
    String? driverName,
  }) async {
    try {
      final id =
          expenseData['id'] ?? 'EXP-${DateTime.now().millisecondsSinceEpoch}';
      expenseData['id'] = id;
      expenseData['status'] = 'Pending';
      expenseData.putIfAbsent('ownerId', () => ownerKey);
      expenseData.putIfAbsent('driverPhone', () => ownerKey);
      expenseData['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('expenses').doc(id).set(
            expenseData,
            SetOptions(merge: true),
          );
      await notifyAdmins(
        title: 'New Expense Claim 🧾',
        body: '${driverName ?? 'Driver'} submitted '
            '${expenseData['title'] ?? 'an expense'} '
            '${expenseData['amount'] ?? ''}'
            '${(expenseData['tripId'] ?? '').toString().isNotEmpty ? ' for trip ${expenseData['tripId']}' : ''}. '
            'Approve or reject.',
        type: 'expense_submitted',
        tripId: expenseData['tripId']?.toString(),
        refId: id,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getExpense(String expenseId) async {
    try {
      final doc = await _db.collection('expenses').doc(expenseId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data != null) data['id'] = doc.id;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> approveExpenseById(String expenseId, {String? adminName}) async {
    try {
      final data =
          (await _db.collection('expenses').doc(expenseId).get()).data() ?? {};
      if (data['status'] != 'Pending') return; // already handled
      await _db
          .collection('expenses')
          .doc(expenseId)
          .set({'status': 'Approved'}, SetOptions(merge: true));
      final driverPhone =
          (data['driverPhone'] ?? data['ownerId'])?.toString() ?? '';
      if (driverPhone.isNotEmpty) {
        await createNotification(
          toPhone: driverPhone,
          title: 'Expense Approved ✅',
          body: '${data['title'] ?? 'Your expense'} ${data['amount'] ?? ''} '
              'was approved.',
          type: 'expense_approved',
          tripId: data['tripId']?.toString(),
        );
      }
    } catch (_) {}
  }

  Future<void> rejectExpenseById(String expenseId,
      {String reason = '', String? adminName}) async {
    try {
      final data =
          (await _db.collection('expenses').doc(expenseId).get()).data() ?? {};
      if (data['status'] != 'Pending') return; // already handled
      await _db.collection('expenses').doc(expenseId).set(
          {'status': 'Rejected', 'rejectReason': reason},
          SetOptions(merge: true));
      final driverPhone =
          (data['driverPhone'] ?? data['ownerId'])?.toString() ?? '';
      if (driverPhone.isNotEmpty) {
        await createNotification(
          toPhone: driverPhone,
          title: 'Expense Rejected ❌',
          body: '${data['title'] ?? 'Your expense'} was rejected.'
              '${reason.isNotEmpty ? ' Reason: $reason' : ''}',
          type: 'expense_rejected',
          tripId: data['tripId']?.toString(),
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS  (in-app, recipient-scoped by phone)
  // ---------------------------------------------------------------------------

  Future<void> createNotification({
    required String toPhone,
    required String title,
    required String body,
    String type = 'info',
    String? tripId,
    String? refId,
  }) async {
    final p = SessionService.normalizePhone(toPhone);
    if (p.isEmpty) return;
    try {
      final keyId = (tripId != null && tripId.isNotEmpty)
          ? tripId
          : (refId != null && refId.isNotEmpty)
              ? refId
              : '${DateTime.now().microsecondsSinceEpoch}_${_db.collection('notifications').doc().id}';
      final docId = '${p}_${type}_$keyId';

      await _db.collection('notifications').doc(docId).set({
        'toPhone': p,
        'title': title,
        'body': body,
        'type': type,
        if (tripId != null) 'tripId': tripId,
        if (refId != null) 'refId': refId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Live notifications for a user, newest first. Sorted client-side so no
  /// composite index is required.
  Stream<List<Map<String, dynamic>>> watchNotifications(String phone) {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return Stream.value(const []);
    return _db
        .collection('notifications')
        .where('toPhone', isEqualTo: p)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) {
        final m = d.data();
        m['id'] = d.id;
        return m;
      }).toList();
      list.sort((a, b) {
        final da = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final db = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      return list;
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications(String phone) async {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return [];
    try {
      final snap = await _db
          .collection('notifications')
          .where('toPhone', isEqualTo: p)
          .get();
      final list = snap.docs.map((d) {
        final m = d.data();
        m['id'] = d.id;
        return m;
      }).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _db
          .collection('notifications')
          .doc(id)
          .set({'read': true}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Mark a notification's action as taken so its Approve/Reject buttons hide
  /// (one-time action per notification).
  Future<void> markNotificationActioned(String id) async {
    try {
      await _db
          .collection('notifications')
          .doc(id)
          .set({'actioned': true, 'read': true}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead(String phone) async {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return;
    try {
      final snap = await _db
          .collection('notifications')
          .where('toPhone', isEqualTo: p)
          .where('read', isEqualTo: false)
          .get();
      await _setInBatches(
          snap.docs.map((doc) => doc.reference), {'read': true});
    } catch (_) {}
  }

  /// Save this device's FCM token so a Cloud Function can push to the user.
  Future<void> saveFcmToken(String phone, String token) async {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty || token.isEmpty) return;
    try {
      await _db.collection('users').doc(p).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Send a notification to every admin (e.g. driver availability updates).
  Future<void> notifyAdmins({
    required String title,
    required String body,
    String type = 'info',
    String? tripId,
    String? refId,
  }) async {
    try {
      final snap =
          await _db.collection('users').where('role', isEqualTo: 'admin').get();
      // All writes are independent but should reach admins together. A batch
      // avoids one round trip per administrator and queues safely offline.
      for (var start = 0; start < snap.docs.length; start += 500) {
        final batch = _db.batch();
        for (final admin in snap.docs.skip(start).take(500)) {
          final keyId = (tripId != null && tripId.isNotEmpty)
              ? tripId
              : (refId != null && refId.isNotEmpty)
                  ? refId
                  : '${DateTime.now().microsecondsSinceEpoch}_${admin.id}';
          final noteRef =
              _db.collection('notifications').doc('${admin.id}_${type}_$keyId');
          batch.set(
              noteRef,
              {
                'toPhone': admin.id,
                'title': title,
                'body': body,
                'type': type,
                if (tripId != null) 'tripId': tripId,
                if (refId != null) 'refId': refId,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // DRIVER CHECK-IN / CHECK-OUT  (duty availability + last-known duty location)
  // ---------------------------------------------------------------------------

  /// Driver goes on duty: captured GPS location + marked Available. Availability
  /// is written to both the user directory (so admin sees it) and the driver
  /// profile, and every admin is notified.
  Future<void> checkIn(
    String phone, {
    required double latitude,
    required double longitude,
    required String address,
    String? driverName,
  }) async {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return;
    final data = <String, dynamic>{
      'availability': 'available',
      'checkedIn': true,
      'lastCheckInAt': FieldValue.serverTimestamp(),
      'checkInLatitude': latitude,
      'checkInLongitude': longitude,
      'checkInAddress': address,
    };
    try {
      await _db.collection('users').doc(p).set(data, SetOptions(merge: true));
      await _db.collection('drivers').doc(p).set(data, SetOptions(merge: true));
      await notifyAdmins(
        title: 'Driver On Duty 🟢',
        body: '${driverName ?? p} checked in and is Available'
            '${address.isNotEmpty ? ' at $address' : ''}.',
        type: 'check_in',
      );
    } catch (_) {}
  }

  /// Driver goes off duty: marked Off Duty; admins notified.
  Future<void> checkOut(String phone, {String? driverName}) async {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return;
    final data = <String, dynamic>{
      'availability': 'off_duty',
      'checkedIn': false,
      'lastCheckOutAt': FieldValue.serverTimestamp(),
    };
    try {
      await _db.collection('users').doc(p).set(data, SetOptions(merge: true));
      await _db.collection('drivers').doc(p).set(data, SetOptions(merge: true));
      await notifyAdmins(
        title: 'Driver Off Duty 🔴',
        body: '${driverName ?? p} checked out.',
        type: 'check_out',
      );
    } catch (_) {}
  }

  /// Live user directory for the admin (roles + availability update in place).
  Stream<List<Map<String, dynamic>>> watchAllUsers() {
    return _db.collection('users').snapshots().map((s) => s.docs.map((d) {
          final m = d.data();
          m['phone'] = d.id;
          return m;
        }).toList());
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
        'timestamp': DateTime.now()
            .toIso8601String()
            .split('T')
            .join(' ')
            .substring(0, 16),
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
      if (remainingDistance != null)
        updates['remainingDistance'] = remainingDistance;
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

  Future<String> uploadProofOfDelivery(String tripId, Uint8List? bytes) async {
    final owner = ownerKey.isEmpty ? 'unknown' : ownerKey;
    const placeholder =
        'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=600';
    if (bytes == null || bytes.isEmpty || useMockStorage) return placeholder;
    try {
      final ref = _storage
          .ref()
          .child('proof_of_delivery')
          .child(owner)
          .child('$tripId.jpg');
      final task =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Proof of Delivery', e);
      throw Exception('Proof of Delivery upload failed: $e');
    }
  }

  /// Saves the uploaded POD proof + remarks on the trip. Deliberately does NOT
  /// mark the trip DELIVERED — that only happens after the admin verifies the
  /// proof and approves ([approveDelivery]). The delivery request itself is
  /// raised separately via [requestDelivery].
  Future<void> saveProofOfDeliveryDetails(
    String tripId,
    String downloadUrl,
    String remarks, {
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
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

  Future<void> updateDriverProfile(Map<String, dynamic> data,
      [String? key]) async {
    try {
      final id = (key == null || key.isEmpty) ? ownerKey : key;
      await _ownerDoc(id).set(data, SetOptions(merge: true));

      final userUpdates = <String, dynamic>{};
      if (data.containsKey('driverName')) {
        userUpdates['name'] = data['driverName'];
      }
      if (data.containsKey('name')) {
        userUpdates['name'] = data['name'];
      }
      if (data.containsKey('avatarUrl')) {
        userUpdates['avatarUrl'] = data['avatarUrl'];
      }
      if (userUpdates.isNotEmpty) {
        await _db
            .collection('users')
            .doc(id)
            .set(userUpdates, SetOptions(merge: true));
      }
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
      await _ownerDoc(key)
          .set({'documents': docsList}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<String> uploadDriverAvatar(Uint8List? bytes, [String? key]) async {
    final owner = (key == null || key.isEmpty) ? ownerKey : key;
    const placeholder =
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop';
    if (bytes == null || bytes.isEmpty || useMockStorage) return placeholder;
    try {
      final ref = _storage
          .ref()
          .child('avatars')
          .child('${owner.isEmpty ? 'unknown' : owner}.jpg');
      final uploadTask =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Driver Avatar', e);
      return '';
    }
  }

  /// Uploads a driver document image (photo / driving licence / heavy-vehicle
  /// licence) under `driver_documents/{phone}/{docType}.jpg` and returns the
  /// download URL. Returns '' when there's nothing to upload or Storage isn't
  /// available (web + mobile safe — takes bytes, not a dart:io File).
  Future<String> uploadDriverDocument(
      String phone, String docType, Uint8List? bytes) async {
    final p = SessionService.normalizePhone(phone);
    if (bytes == null || bytes.isEmpty || useMockStorage) return '';
    try {
      final ref = _storage
          .ref()
          .child('driver_documents')
          .child(p.isEmpty ? 'unknown' : p)
          .child('$docType.jpg');
      final task =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Driver Document', e);
      return '';
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
      final variants = SessionService.getPhoneVariants(phone);

      // 1. Direct document lookups by ID in `users` collection
      for (final variant in variants) {
        final doc = await _db.collection('users').doc(variant).get();
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['phone'] = doc.id;
          return data;
        }
      }

      // 2. Direct document lookups by ID in `drivers` collection
      for (final variant in variants) {
        final doc = await _db.collection('drivers').doc(variant).get();
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['phone'] = doc.id;
          if (!data.containsKey('role')) {
            data['role'] = 'driver';
          }
          return data;
        }
      }

      // 3. Query `users` collection by `phone` or `phoneNumber` fields
      for (final field in ['phone', 'phoneNumber']) {
        for (final variant in variants) {
          final snap = await _db
              .collection('users')
              .where(field, isEqualTo: variant)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final doc = snap.docs.first;
            final data = Map<String, dynamic>.from(doc.data());
            data['phone'] = doc.id;
            return data;
          }
        }
      }

      // 4. Query `drivers` collection by `phone` or `phoneNumber` fields
      for (final field in ['phone', 'phoneNumber']) {
        for (final variant in variants) {
          final snap = await _db
              .collection('drivers')
              .where(field, isEqualTo: variant)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final doc = snap.docs.first;
            final data = Map<String, dynamic>.from(doc.data());
            data['phone'] = doc.id;
            if (!data.containsKey('role')) {
              data['role'] = 'driver';
            }
            return data;
          }
        }
      }

      // 5. Fallback scan matching 10-digit suffix across `users` collection
      final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (clean.length >= 10) {
        final base10 = clean.substring(clean.length - 10);
        final usersSnap = await _db.collection('users').get();
        for (final doc in usersSnap.docs) {
          final docIdClean = doc.id.replaceAll(RegExp(r'[^\d]'), '');
          final fieldPhone = (doc.data()['phone'] ?? doc.data()['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
          if ((docIdClean.length >= 10 && docIdClean.substring(docIdClean.length - 10) == base10) ||
              (fieldPhone.length >= 10 && fieldPhone.substring(fieldPhone.length - 10) == base10)) {
            final data = Map<String, dynamic>.from(doc.data());
            data['phone'] = doc.id;
            return data;
          }
        }

        // 6. Fallback scan matching 10-digit suffix across `drivers` collection
        final driversSnap = await _db.collection('drivers').get();
        for (final doc in driversSnap.docs) {
          final docIdClean = doc.id.replaceAll(RegExp(r'[^\d]'), '');
          final fieldPhone = (doc.data()['phone'] ?? doc.data()['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
          if ((docIdClean.length >= 10 && docIdClean.substring(docIdClean.length - 10) == base10) ||
              (fieldPhone.length >= 10 && fieldPhone.substring(fieldPhone.length - 10) == base10)) {
            final data = Map<String, dynamic>.from(doc.data());
            data['phone'] = doc.id;
            if (!data.containsKey('role')) {
              data['role'] = 'driver';
            }
            return data;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Links the Firebase Auth UID to the user/driver record in Firestore
  /// and syncs the record across `users` and `drivers` collections.
  Future<void> linkUserUid(String phoneKey, String uid, Map<String, dynamic> userData) async {
    try {
      final updates = <String, dynamic>{
        'uid': uid,
        'phone': phoneKey,
        ...userData,
      };

      await _db.collection('users').doc(phoneKey).set(updates, SetOptions(merge: true));

      final role = (userData['role'] ?? 'driver').toString();
      if (role == 'driver' || role == 'owner') {
        await _db.collection('drivers').doc(phoneKey).set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[FirebaseService] linkUserUid failed: $e');
    }
  }

  Future<void> saveUser(String phone, Map<String, dynamic> userData) {
    return _write(
        'User save nahi hua',
        () async {
          await _db
              .collection('users')
              .doc(phone)
              .set(userData, SetOptions(merge: true));

          final role = (userData['role'] ?? 'driver').toString();
          if (role == 'driver' || role == 'owner') {
            await _db
                .collection('drivers')
                .doc(phone)
                .set(userData, SetOptions(merge: true));
          }
        });
  }

  Future<void> updateUserRole(String phone, String newRole) {
    return _write(
        'Role update nahi hua',
        () => _db
            .collection('users')
            .doc(phone)
            .set({'role': newRole}, SetOptions(merge: true)));
  }

  Future<void> deleteUser(String phone) {
    return _write('User delete nahi hua',
        () => _db.collection('users').doc(phone).delete());
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
      final snapshot = await _db
          .collection('trucks')
          .where('ownerId', isEqualTo: owner)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Live stream of all trucks for the admin (assignment + inspection status).
  Stream<List<Map<String, dynamic>>> watchAllTrucks() {
    return _db.collection('trucks').snapshots().map((s) => s.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList());
  }

  // ---------------------------------------------------------------------------
  // DAILY TRUCK ASSIGNMENT + INSPECTION
  // Morning flow: admin assigns a truck to each driver -> driver inspects it ->
  // either reports a problem (reason + photo, admin notified) or accepts it
  // (truck becomes READY for trips, admin notified).
  // inspectionStatus: 'pending' -> 'problem' | 'ready'
  // ---------------------------------------------------------------------------

  /// Admin assigns [truckNo] to a driver. Any previous assignment of this truck
  /// is replaced and the driver is notified to inspect + accept it.
  Future<void> assignTruckToDriver(String truckNo, String driverPhone,
      {String? model}) async {
    final p = SessionService.normalizePhone(driverPhone);
    if (truckNo.isEmpty || p.isEmpty) return;
    try {
      // Rule: same truck same time 2 driver ko assign nahi ho sakte, and a driver can only have one truck assigned at a time.
      // 1. Unassign this driver from any other trucks
      final existingQuery = await _db
          .collection('trucks')
          .where('assignedTo', isEqualTo: p)
          .get();
      for (final doc in existingQuery.docs) {
        if (doc.id != truckNo) {
          await _updateTruckDoc(
            doc.id,
            {
              'assignedTo': FieldValue.delete(),
              'inspectionStatus': FieldValue.delete(),
              'inspectionIssue': FieldValue.delete(),
              'inspectionIssueImage': FieldValue.delete(),
              'inspectionRemarks': FieldValue.delete(),
              'inspectionResults': FieldValue.delete(),
              'inspectionImages': FieldValue.delete(),
            },
            action: 'assignTruckToDriver_unassign_existing',
          );
        }
      }

      // 2. Assign the truck to this driver (will overwrite any previous driver assigned to this truckNo)
      await _setTruckDoc(
        truckNo,
        {
          'truckNo': truckNo,
          'ownerId': ownerKey,
          if (model != null && model.isNotEmpty) 'model': model,
          'assignedTo': p,
          'assignedBy': ownerKey,
          'assignedAt': FieldValue.serverTimestamp(),
          'inspectionStatus': 'pending_confirmation',
          'inspectionIssue': FieldValue.delete(),
          'inspectionIssueImage': FieldValue.delete(),
          'inspectionRemarks': FieldValue.delete(),
          'inspectionResults': FieldValue.delete(),
          'inspectionImages': FieldValue.delete(),
        },
        options: SetOptions(merge: true),
        action: 'assignTruckToDriver',
      );

      await createNotification(
        toPhone: p,
        title: 'Truck Assigned 🚛',
        body: 'Truck $truckNo aapko assign hua hai. Inspection karke '
            'accept karein ya problem report karein.',
        type: 'truck_assigned',
        refId: truckNo,
      );
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] assignTruckToDriver failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] assignTruckToDriver failed: $e');
      rethrow;
    }
  }

  /// Upload a truck-issue photo (web + mobile safe bytes).
  Future<String> uploadTruckIssueImage(String truckNo, Uint8List? bytes) async {
    final owner = ownerKey.isEmpty ? 'unknown' : ownerKey;
    if (bytes == null || bytes.isEmpty || useMockStorage) return '';
    try {
      final ref = _storage
          .ref()
          .child('truck_issues')
          .child(owner)
          .child('$truckNo.jpg');
      final task =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      _warnStorage('Truck Issue', e);
      return '';
    }
  }

  /// Driver accepts the truck assignment (transitions status from pending_confirmation to pending)
  Future<void> acceptTruckAssignment(
      String truckNo, String sessionPhone) async {
    if (truckNo.isEmpty) return;
    try {
      await _updateTruckDoc(
        truckNo,
        {
          'inspectionStatus': 'pending',
          'assignedTo': sessionPhone,
        },
        action: 'acceptTruckAssignment',
      );
      AppLogger.i('Truck assigned successfully!');
    } on FirebaseException catch (e, st) {
      AppLogger.e('[FirebaseService] acceptTruckAssignment failed', e, st);
      rethrow;
    } catch (e, st) {
      AppLogger.e('[FirebaseService] acceptTruckAssignment failed', e, st);
      rethrow;
    }
  }

  /// Driver reports a problem found during inspection. Admins are notified with
  /// the reason (photo proof saved on the truck doc).
  Future<void> reportTruckIssue(
    String truckNo, {
    required String reason,
    String imageUrl = '',
    String? driverName,
  }) async {
    if (truckNo.isEmpty) return;
    try {
      await _setTruckDoc(
        truckNo,
        {
          'inspectionStatus': 'problem',
          'inspectionIssue': reason,
          if (imageUrl.isNotEmpty) 'inspectionIssueImage': imageUrl,
          'inspectedAt': FieldValue.serverTimestamp(),
        },
        options: SetOptions(merge: true),
        action: 'reportTruckIssue',
      );

      await notifyAdmins(
        title: 'Truck Problem ⚠️',
        body: '${driverName ?? 'Driver'} ke truck $truckNo me problem: $reason',
        type: 'truck_issue',
        refId: truckNo,
      );
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] reportTruckIssue failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] reportTruckIssue failed: $e');
      rethrow;
    }
  }

  /// Driver submits truck inspection for review.
  Future<void> submitTruckInspection(
    String truckNo, {
    required Map<String, bool> results,
    required String remarks,
    required List<String> imageUrls,
    required String driverName,
  }) async {
    if (truckNo.isEmpty) return;
    final hasIssues = results.values.any((good) => !good);
    final failedItems =
        results.entries.where((e) => !e.value).map((e) => e.key).toList();
    final reason = [
      if (failedItems.isNotEmpty) failedItems.join(', '),
      if (remarks.trim().isNotEmpty) remarks.trim(),
    ].join(' — ');

    await _setTruckDoc(
      truckNo,
      {
        'inspectionStatus': hasIssues ? 'problem' : 'ready',
        'inspectionResults': results,
        'inspectionRemarks': remarks,
        'inspectionImages': imageUrls,
        'inspectionIssue': reason.isNotEmpty ? reason : 'All items good',
        'inspectedAt': FieldValue.serverTimestamp(),
      },
      options: SetOptions(merge: true),
      action: 'submitTruckInspection',
    );

    await notifyAdmins(
      title: hasIssues ? 'Truck Inspection (Issue) ⚠️' : 'Truck Ready ✅',
      body: hasIssues
          ? '$driverName ne truck $truckNo par issue report kiya.'
          : '$driverName ka truck $truckNo thik hai — trip ke liye ready.',
      type: hasIssues ? 'truck_inspection_submitted' : 'truck_ready',
      refId: truckNo,
    );
  }

  /// Admin approves the truck inspection condition.
  Future<void> approveTruckInspection(String truckNo) async {
    if (truckNo.isEmpty) return;
    final data =
        (await _db.collection('trucks').doc(truckNo).get()).data() ?? {};
    final driver = (data['assignedTo'] ?? '').toString();

    await _setTruckDoc(
      truckNo,
      {
        'inspectionStatus': 'approved_pending_accept',
      },
      options: SetOptions(merge: true),
      action: 'approveTruckInspection',
    );

    if (driver.isNotEmpty) {
      await createNotification(
        toPhone: driver,
        title: 'Inspection Approved ✅',
        body:
            'Truck $truckNo ka inspection approve ho gaya hai. Dashboard par accept karein.',
        type: 'inspection_approved',
        refId: truckNo,
      );
    }
  }

  /// Admin rejects/requests re-inspection of the truck.
  Future<void> rejectTruckInspection(String truckNo) async {
    if (truckNo.isEmpty) return;
    final data =
        (await _db.collection('trucks').doc(truckNo).get()).data() ?? {};
    final driver = (data['assignedTo'] ?? '').toString();

    await _setTruckDoc(
      truckNo,
      {
        'inspectionStatus':
            'pending', // back to pending state so they re-inspect
        'inspectionRemarks': FieldValue.delete(),
        'inspectionResults': FieldValue.delete(),
        'inspectionImages': FieldValue.delete(),
        'inspectionIssue': FieldValue.delete(),
        'inspectionIssueImage': FieldValue.delete(),
      },
      options: SetOptions(merge: true),
      action: 'rejectTruckInspection',
    );

    if (driver.isNotEmpty) {
      await createNotification(
        toPhone: driver,
        title: 'Inspection Rejected ❌',
        body:
            'Truck $truckNo ka inspection reject ho gaya hai. Kripya fir se inspect karein.',
        type: 'inspection_rejected',
        refId: truckNo,
      );
    }
  }

  /// Driver confirms the truck's condition is proper — it becomes READY for
  /// trips and the admins are informed.
  Future<void> acceptTruck(String truckNo, {String? driverName}) async {
    if (truckNo.isEmpty) return;
    try {
      await _setTruckDoc(
        truckNo,
        {
          'inspectionStatus': 'ready',
          'inspectionIssue': FieldValue.delete(),
          'inspectionIssueImage': FieldValue.delete(),
          'inspectedAt': FieldValue.serverTimestamp(),
        },
        options: SetOptions(merge: true),
        action: 'acceptTruck',
      );

      await notifyAdmins(
        title: 'Truck Ready ✅',
        body: '${driverName ?? 'Driver'} ka truck $truckNo thik hai — '
            'trip ke liye ready.',
        type: 'truck_ready',
        refId: truckNo,
      );
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] acceptTruck failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] acceptTruck failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTruck(String truckNo) async {
    try {
      final doc = await _db.collection('trucks').doc(truckNo).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data != null) data['id'] = doc.id;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Admin resolves a reported truck problem — truck goes back to READY and the
  /// assigned driver is informed.
  Future<void> clearTruckIssue(String truckNo) async {
    if (truckNo.isEmpty) return;
    try {
      final data =
          (await _db.collection('trucks').doc(truckNo).get()).data() ?? {};
      await _setTruckDoc(
        truckNo,
        {
          'inspectionStatus': 'ready',
          'inspectionIssue': FieldValue.delete(),
          'inspectionIssueImage': FieldValue.delete(),
        },
        options: SetOptions(merge: true),
        action: 'clearTruckIssue',
      );
      final driver = (data['assignedTo'] ?? '').toString();
      if (driver.isNotEmpty) {
        await createNotification(
          toPhone: driver,
          title: 'Truck Active ✅',
          body: 'Truck $truckNo ki problem resolve ho gayi — truck ab '
              'active/ready hai.',
          type: 'truck_ready',
          refId: truckNo,
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] clearTruckIssue failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] clearTruckIssue failed: $e');
      rethrow;
    }
  }

  /// Admin clears assignment for a truck.
  Future<void> unassignTruck(String truckNo) async {
    if (truckNo.isEmpty) return;
    try {
      debugPrint('[FirebaseService] unassignTruck called for $truckNo');
      debugPrintStack();
      await _updateTruckDoc(
        truckNo,
        {
          'assignedTo': FieldValue.delete(),
          'assignedBy': FieldValue.delete(),
          'assignedAt': FieldValue.delete(),
          'inspectionStatus': FieldValue.delete(),
          'inspectionIssue': FieldValue.delete(),
          'inspectionIssueImage': FieldValue.delete(),
          'inspectionRemarks': FieldValue.delete(),
          'inspectionResults': FieldValue.delete(),
          'inspectionImages': FieldValue.delete(),
          'loadingPass': FieldValue.delete(),
          'hasLoadingPass': FieldValue.delete(),
          'destinationSetup': FieldValue.delete(),
          'hasDestinationSetup': FieldValue.delete(),
        },
        action: 'unassignTruck',
      );

      // Clean up any active/pending trips for this truck
      try {
        final tripsSnap = await _db.collection('trips').get();
        String clean(String val) =>
            val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
        final targetClean = clean(truckNo);
        for (final doc in tripsSnap.docs) {
          final data = doc.data();
          final tripTruck = (data['truckNo'] ?? '').toString();
          final status = (data['status'] ?? '').toString();
          if (clean(tripTruck) == targetClean &&
              status != 'DELIVERED' &&
              status != 'REJECTED') {
            await doc.reference.delete();
          }
        }
      } catch (e) {
        debugPrint('[FirebaseService] unassignTruck trip cleanup error: $e');
      }
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] unassignTruck failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] unassignTruck failed: $e');
      rethrow;
    }
  }

  /// Admin saves loading pass details for a truck.
  Future<void> saveLoadingPass(
      String truckNo, Map<String, dynamic> passData) async {
    if (truckNo.isEmpty) return;
    try {
      await _setTruckDoc(
        truckNo,
        {
          'loadingPass': passData,
          'hasLoadingPass': true,
        },
        options: SetOptions(merge: true),
        action: 'saveLoadingPass',
      );
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] saveLoadingPass failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] saveLoadingPass failed: $e');
      rethrow;
    }
  }

  /// Admin saves destination setup details for a truck.
  Future<void> saveDestinationSetup(
      String truckNo, Map<String, dynamic> destData) async {
    if (truckNo.isEmpty) return;
    try {
      await _setTruckDoc(
        truckNo,
        {
          'destinationSetup': destData,
          'hasDestinationSetup': true,
        },
        options: SetOptions(merge: true),
        action: 'saveDestinationSetup',
      );
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseService] saveDestinationSetup failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseService] saveDestinationSetup failed: $e');
      rethrow;
    }
  }

  /// Live: the truck currently assigned to this driver (null if none).
  Stream<Map<String, dynamic>?> watchTruckForDriver(String phone) {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return Stream.value(null);
    return _db
        .collection('trucks')
        .where('assignedTo', isEqualTo: p)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return null;
      final m = s.docs.first.data();
      m['id'] = s.docs.first.id;
      return m;
    });
  }

  Future<void> _logTruckWrite(
      String truckNo, Map<String, dynamic> payload, String action) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final session = Get.find<SessionService>();
      final isUserAdmin = session.isAdmin;
      AppLogger.d("Project Id: ${Firebase.app().options.projectId}");
      AppLogger.d("UID: ${user?.uid}");
      AppLogger.d("Phone: ${user?.phoneNumber}");
      final docSnapshot = await _db.collection('trucks').doc(truckNo).get();
      final existingDoc = docSnapshot.data() ?? {};

      // Calculate merged document
      final mergedDoc = Map<String, dynamic>.from(existingDoc);
      payload.forEach((key, value) {
        if (value is FieldValue) {
          if (value.toString().contains('delete')) {
            mergedDoc.remove(key);
          } else {
            mergedDoc[key] = '<FieldValue>';
          }
        } else {
          mergedDoc[key] = value;
        }
      });

      debugPrint('--- FIRESTORE WRITE DEBUG LOGS ($action) ---');
      debugPrint('Write target path: trucks/$truckNo');
      debugPrint('Full existing document: $existingDoc');
      debugPrint('Full update payload: $payload');
      debugPrint('Merged document after update: $mergedDoc');
      debugPrint('Authenticated UID: ${user?.uid}');
      debugPrint('Authenticated phone: ${user?.phoneNumber}');
      debugPrint('Session phone: ${session.phone.value}');
      debugPrint('ownerId: ${mergedDoc['ownerId']}');
      debugPrint('assignedTo: ${mergedDoc['assignedTo']}');
      debugPrint('Admin role: ${session.role.value}');
      debugPrint('Firestore rule expected to pass: '
          '${isUserAdmin ? "isAdmin()" : "ownsIncoming() / ownsExisting() / isPhoneMatch(assignedTo)"}');
      debugPrint('-------------------------------------------');
    } catch (e) {
      debugPrint('Error printing debug logs: $e');
    }
  }

  Future<void> _setTruckDoc(
    String truckNo,
    Map<String, dynamic> data, {
    SetOptions? options,
    required String action,
  }) async {
    await _logTruckWrite(truckNo, data, action);
    final docRef = _db.collection('trucks').doc(truckNo);
    await _write(
      'Truck doc set failed ($action)',
      () => options != null ? docRef.set(data, options) : docRef.set(data),
    );
  }

  Future<void> _updateTruckDoc(
    String truckNo,
    Map<String, dynamic> data, {
    required String action,
  }) async {
    await _logTruckWrite(truckNo, data, action);
    final docRef = _db.collection('trucks').doc(truckNo);
    await _write(
      'Truck doc update failed ($action)',
      () => docRef.update(data),
    );
  }

  Future<void> saveTruck(String truckId, Map<String, dynamic> truckData) {
    truckData.putIfAbsent('ownerId', () => ownerKey);
    return _setTruckDoc(truckId, truckData,
        options: SetOptions(merge: true), action: 'saveTruck');
  }

  Future<void> deleteTruck(String truckId) {
    return _write('Truck delete nahi hua',
        () => _db.collection('trucks').doc(truckId).delete());
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

  /// Live driver-scoped expenses. The driver's list must reflect an admin's
  /// approve/reject the moment it happens — a one-shot read left the status
  /// stale until a manual refresh.
  Stream<List<Map<String, dynamic>>> watchExpensesForDriver(String phone) {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return Stream.value(const []);
    return _db
        .collection('expenses')
        .where('driverPhone', isEqualTo: p)
        .snapshots()
        .map((s) => s.docs.map((d) {
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
      final snapshot = await _db
          .collection('expenses')
          .where('tripId', isEqualTo: tripId)
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

  Future<void> saveExpense(Map<String, dynamic> expenseData) async {
    try {
      expenseData.putIfAbsent('ownerId', () => ownerKey);
      final id =
          expenseData['id'] ?? 'EXP-${DateTime.now().millisecondsSinceEpoch}';
      await _db
          .collection('expenses')
          .doc(id)
          .set(expenseData, SetOptions(merge: true));
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

  // ---------------------------------------------------------------------------
  // VENDORS  (predefined pickup sources — admin creates once, then just assigns
  // them to trips). A vendor holds its location details; per-trip fields like
  // material / pass holder / royalty / loading pass are entered on the trip.
  // ---------------------------------------------------------------------------

  /// Live stream of all vendors for the admin vendor directory + trip form.
  Stream<List<Map<String, dynamic>>> watchVendors() {
    return _db.collection('vendors').snapshots().map((s) => s.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList());
  }

  Future<List<Map<String, dynamic>>> getVendors() async {
    try {
      final snap = await _db.collection('vendors').get();
      return snap.docs.map((d) {
        final m = d.data();
        m['id'] = d.id;
        return m;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Create or update a vendor. Generates an id when one isn't supplied.
  Future<String> saveVendor(Map<String, dynamic> vendorData) async {
    final id = (vendorData['id'] ?? '').toString().isNotEmpty
        ? vendorData['id'].toString()
        : 'VEND-${DateTime.now().millisecondsSinceEpoch}';
    vendorData['id'] = id;
    vendorData.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
    await _write(
        'Vendor save nahi hua',
        () => _db
            .collection('vendors')
            .doc(id)
            .set(vendorData, SetOptions(merge: true)));
    return id;
  }

  Future<void> deleteVendor(String id) {
    return _write('Vendor delete nahi hua',
        () => _db.collection('vendors').doc(id).delete());
  }

  // ---------------------------------------------------------------------------
  // CUSTOMERS (delivery destinations / customers directory)
  // ---------------------------------------------------------------------------

  /// Live stream of all customers for admin directory + trip form.
  Stream<List<Map<String, dynamic>>> watchCustomers() {
    return _db.collection('customers').snapshots().map((s) => s.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList());
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final snap = await _db.collection('customers').get();
      return snap.docs.map((d) {
        final m = d.data();
        m['id'] = d.id;
        return m;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Create or update a customer. Generates an id when one isn't supplied.
  Future<String> saveCustomer(Map<String, dynamic> customerData) async {
    final id = (customerData['id'] ?? '').toString().isNotEmpty
        ? customerData['id'].toString()
        : 'CUST-${DateTime.now().millisecondsSinceEpoch}';
    customerData['id'] = id;
    customerData.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
    await _write(
        'Customer save nahi hua',
        () => _db
            .collection('customers')
            .doc(id)
            .set(customerData, SetOptions(merge: true)));
    return id;
  }

  Future<void> deleteCustomer(String id) {
    return _write('Customer delete nahi hua',
        () => _db.collection('customers').doc(id).delete());
  }

  /// Admin marks a driver on leave (or back on duty). On-leave drivers are
  /// excluded from the daily truck-assignment gate and from trip assignment.
  Future<void> setDriverLeave(String phone, bool onLeave) async {
    final p = SessionService.normalizePhone(phone);
    if (p.isEmpty) return;
    final data = {
      'onLeave': onLeave,
      if (onLeave) 'availability': 'on_leave',
    };
    try {
      await _db.collection('users').doc(p).set(data, SetOptions(merge: true));
      await _db.collection('drivers').doc(p).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Sequential-ish, human-readable trip id: `TRP-YYMMDD-XXX`, where XXX is the
  /// next number for today (based on how many trips already exist for the date
  /// prefix). Auto-generated so the admin never types a trip id.
  Future<String> generateTripId() async {
    final now = DateTime.now();
    final y = (now.year % 100).toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final prefix = 'TRP-$y$m$d';
    var maxSeq = 0;
    try {
      final snap = await _db.collection('trips').get();
      for (final doc in snap.docs) {
        if (doc.id.startsWith('$prefix-')) {
          final seq = int.tryParse(doc.id.substring(prefix.length + 1)) ?? 0;
          if (seq > maxSeq) maxSeq = seq;
        }
      }
    } catch (_) {
      return '$prefix-${(now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';
    }
    return '$prefix-${(maxSeq + 1).toString().padLeft(3, '0')}';
  }

  void _warnStorage(String what, Object e) {
    debugPrint('------------------------------------------------------------');
    debugPrint('WARNING: Firebase Storage upload failed for $what: $e');
    debugPrint(
        'If you see a 404, your Firebase Storage bucket is not enabled.');
    debugPrint('Open Firebase Console > Storage > Get Started to enable it.');
    debugPrint('Falling back to the local file path for now.');
    debugPrint('------------------------------------------------------------');
  }

  Future<void> clearDatabase() async {
    try {
      // 1. Delete all trips
      final trips = await _db.collection('trips').get();
      for (var doc in trips.docs) {
        await doc.reference.delete();
      }

      // 2. Delete all expenses
      final expenses = await _db.collection('expenses').get();
      for (var doc in expenses.docs) {
        await doc.reference.delete();
      }

      // 3. Delete all notifications
      final notifications = await _db.collection('notifications').get();
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      // 4. Delete all trucks
      final trucks = await _db.collection('trucks').get();
      for (var doc in trucks.docs) {
        await doc.reference.delete();
      }

      // 5. Delete all users except current admin
      final users = await _db.collection('users').get();
      for (var doc in users.docs) {
        if (doc.id != ownerKey) {
          await doc.reference.delete();
        }
      }

      // 6. Delete all drivers except current admin (if driver)
      final drivers = await _db.collection('drivers').get();
      for (var doc in drivers.docs) {
        if (doc.id != ownerKey) {
          await doc.reference.delete();
        }
      }

      // Reset the seededDemo flag on the current user so they don't get re-seeded automatically
      if (ownerKey.isNotEmpty) {
        try {
          await _db
              .collection('users')
              .doc(ownerKey)
              .update({'seededDemo': false});
        } catch (_) {}
        try {
          await _db
              .collection('drivers')
              .doc(ownerKey)
              .update({'seededDemo': false});
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error clearing database: $e');
    }
  }

  Future<void> migratePhoneKeys() async {
    if (_phoneKeysMigrated) return;
    try {
      bool isUserAdmin = false;
      try {
        final session = Get.find<SessionService>();
        isUserAdmin = session.role.value == 'admin';
      } catch (_) {
        isUserAdmin = _ownerKeyResolver != null;
      }

      if (!isUserAdmin) {
        return;
      }

      _phoneKeysMigrated = true;
      debugPrint('[Migration] Starting phone number key migration...');
      // 1. Migrate Users
      final users = await _db.collection('users').get();
      for (var doc in users.docs) {
        final id = doc.id;
        if (id.startsWith('+')) {
          final newId = id.replaceFirst('+', '');
          final data = doc.data();
          if (data['phone'] != null) {
            data['phone'] = (data['phone'] as String).replaceFirst('+', '');
          }
          await _db
              .collection('users')
              .doc(newId)
              .set(data, SetOptions(merge: true));
          await doc.reference.delete();
          debugPrint('[Migration] Migrated user $id to $newId');
        }
      }

      // 2. Migrate Drivers
      final drivers = await _db.collection('drivers').get();
      for (var doc in drivers.docs) {
        final id = doc.id;
        if (id.startsWith('+')) {
          final newId = id.replaceFirst('+', '');
          final data = doc.data();
          if (data['phone'] != null) {
            data['phone'] = (data['phone'] as String).replaceFirst('+', '');
          }
          await _db
              .collection('drivers')
              .doc(newId)
              .set(data, SetOptions(merge: true));
          await doc.reference.delete();
          debugPrint('[Migration] Migrated driver $id to $newId');
        }
      }

      // 3. Migrate Trucks (fields ownerId, assignedTo)
      final trucks = await _db.collection('trucks').get();
      for (var doc in trucks.docs) {
        final data = doc.data();
        bool changed = false;
        if (data['ownerId'] != null &&
            (data['ownerId'] as String).startsWith('+')) {
          data['ownerId'] = (data['ownerId'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (data['assignedTo'] != null &&
            (data['assignedTo'] as String).startsWith('+')) {
          data['assignedTo'] =
              (data['assignedTo'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (data['assignedBy'] != null &&
            (data['assignedBy'] as String).startsWith('+')) {
          data['assignedBy'] =
              (data['assignedBy'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (changed) {
          await doc.reference.set(data, SetOptions(merge: true));
          debugPrint('[Migration] Migrated fields for truck ${doc.id}');
        }
      }

      // 4. Migrate Trips (fields ownerId, driverPhone, assignedBy)
      final trips = await _db.collection('trips').get();
      for (var doc in trips.docs) {
        final data = doc.data();
        bool changed = false;
        if (data['ownerId'] != null &&
            (data['ownerId'] as String).startsWith('+')) {
          data['ownerId'] = (data['ownerId'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (data['driverPhone'] != null &&
            (data['driverPhone'] as String).startsWith('+')) {
          data['driverPhone'] =
              (data['driverPhone'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (data['assignedBy'] != null &&
            (data['assignedBy'] as String).startsWith('+')) {
          data['assignedBy'] =
              (data['assignedBy'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (changed) {
          await doc.reference.set(data, SetOptions(merge: true));
          debugPrint('[Migration] Migrated fields for trip ${doc.id}');
        }
      }

      // 5. Migrate Expenses (fields ownerId, driverPhone)
      final expenses = await _db.collection('expenses').get();
      for (var doc in expenses.docs) {
        final data = doc.data();
        bool changed = false;
        if (data['ownerId'] != null &&
            (data['ownerId'] as String).startsWith('+')) {
          data['ownerId'] = (data['ownerId'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (data['driverPhone'] != null &&
            (data['driverPhone'] as String).startsWith('+')) {
          data['driverPhone'] =
              (data['driverPhone'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (changed) {
          await doc.reference.set(data, SetOptions(merge: true));
          debugPrint('[Migration] Migrated fields for expense ${doc.id}');
        }
      }

      // 6. Migrate Notifications (toPhone)
      final notifications = await _db.collection('notifications').get();
      for (var doc in notifications.docs) {
        final data = doc.data();
        bool changed = false;
        if (data['toPhone'] != null &&
            (data['toPhone'] as String).startsWith('+')) {
          data['toPhone'] = (data['toPhone'] as String).replaceFirst('+', '');
          changed = true;
        }
        if (changed) {
          await doc.reference.set(data, SetOptions(merge: true));
          debugPrint('[Migration] Migrated fields for notification ${doc.id}');
        }
      }

      debugPrint('[Migration] Migration completed successfully.');
    } catch (e) {
      debugPrint('[Migration] Migration failed: $e');
    }
  }
}
