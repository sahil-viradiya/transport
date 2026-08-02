import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository interface for Driver domain operations.
abstract class IDriverRepository {
  Future<Map<String, dynamic>?> getDriverProfile(String ownerKey);
  Stream<Map<String, dynamic>?> watchDriverProfile(String ownerKey);
  Future<List<Map<String, dynamic>>> getActiveDrivers();
  Stream<List<Map<String, dynamic>>> watchActiveDrivers();
  Future<void> updateDriverProfile(String ownerKey, Map<String, dynamic> data);
}

/// Firestore implementation of [IDriverRepository].
class DriverRepository implements IDriverRepository {
  final FirebaseFirestore _db;

  DriverRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> getDriverProfile(String ownerKey) async {
    if (ownerKey.isEmpty) return null;
    final doc = await _db.collection('drivers').doc(ownerKey).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    data['id'] = doc.id;
    return data;
  }

  @override
  Stream<Map<String, dynamic>?> watchDriverProfile(String ownerKey) {
    if (ownerKey.isEmpty) return Stream.value(null);
    return _db.collection('drivers').doc(ownerKey).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      data['id'] = doc.id;
      return data;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveDrivers() async {
    final snapshot = await _db.collection('drivers').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchActiveDrivers() {
    return _db.collection('drivers').snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  @override
  Future<void> updateDriverProfile(String ownerKey, Map<String, dynamic> data) async {
    await _db.collection('drivers').doc(ownerKey).set(data, SetOptions(merge: true));
  }
}
