import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository interface for Expense domain operations.
abstract class IExpenseRepository {
  Future<List<Map<String, dynamic>>> getExpensesForDriver(String driverPhone);
  Stream<List<Map<String, dynamic>>> watchExpensesForDriver(String driverPhone);
  Stream<List<Map<String, dynamic>>> watchAllExpensesForAdmin();
  Future<void> createExpense(Map<String, dynamic> data);
  Future<void> updateExpense(String expenseId, Map<String, dynamic> data);
}

/// Firestore implementation of [IExpenseRepository].
class ExpenseRepository implements IExpenseRepository {
  final FirebaseFirestore _db;

  ExpenseRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> getExpensesForDriver(String driverPhone) async {
    if (driverPhone.isEmpty) return [];
    final snapshot = await _db
        .collection('expenses')
        .where('driverPhone', isEqualTo: driverPhone)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchExpensesForDriver(String driverPhone) {
    if (driverPhone.isEmpty) return Stream.value([]);
    return _db
        .collection('expenses')
        .where('driverPhone', isEqualTo: driverPhone)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAllExpensesForAdmin() {
    return _db.collection('expenses').snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  @override
  Future<void> createExpense(Map<String, dynamic> data) async {
    final id = data['id'] as String? ?? _db.collection('expenses').doc().id;
    await _db.collection('expenses').doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> updateExpense(String expenseId, Map<String, dynamic> data) async {
    await _db.collection('expenses').doc(expenseId).update(data);
  }
}
