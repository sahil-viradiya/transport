import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository interface for Trip domain operations.
abstract class ITripRepository {
  Future<List<Map<String, dynamic>>> getTripsForOwner(String ownerKey);
  Stream<List<Map<String, dynamic>>> watchTripsForOwner(String ownerKey);
  Stream<List<Map<String, dynamic>>> watchAllTripsForAdmin();
  Future<Map<String, dynamic>?> getTripById(String tripId);
  Future<void> updateTrip(String tripId, Map<String, dynamic> data);
  Future<DocumentReference<Map<String, dynamic>>> createTrip(Map<String, dynamic> data);
}

/// Firestore implementation of [ITripRepository].
class TripRepository implements ITripRepository {
  final FirebaseFirestore _db;

  TripRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> getTripsForOwner(String ownerKey) async {
    if (ownerKey.isEmpty) return [];
    final snapshot = await _db
        .collection('trips')
        .where('ownerId', isEqualTo: ownerKey)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripsForOwner(String ownerKey) {
    if (ownerKey.isEmpty) return Stream.value([]);
    return _db
        .collection('trips')
        .where('ownerId', isEqualTo: ownerKey)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAllTripsForAdmin() {
    return _db.collection('trips').snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  @override
  Future<Map<String, dynamic>?> getTripById(String tripId) async {
    final doc = await _db.collection('trips').doc(tripId).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    data['id'] = doc.id;
    return data;
  }

  @override
  Future<void> updateTrip(String tripId, Map<String, dynamic> data) async {
    await _db.collection('trips').doc(tripId).update(data);
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> createTrip(Map<String, dynamic> data) async {
    return await _db.collection('trips').add(data);
  }
}
