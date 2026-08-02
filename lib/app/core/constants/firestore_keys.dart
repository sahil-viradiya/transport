/// Centralized Firestore collection names and field keys.
class FirestoreKeys {
  FirestoreKeys._();

  // Collection Names
  static const String colUsers = 'users';
  static const String colTrips = 'trips';
  static const String colTrucks = 'trucks';
  static const String colExpenses = 'expenses';
  static const String colNotifications = 'notifications';
  static const String colVendors = 'vendors';
  static const String colCustomers = 'customers';
  static const String colInspections = 'inspections';

  // Shared Field Keys
  static const String fieldId = 'id';
  static const String fieldName = 'name';
  static const String fieldPhone = 'phone';
  static const String fieldRole = 'role';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';
  static const String fieldOwnerKey = 'ownerKey';
  static const String fieldTruckNo = 'truckNo';
  static const String fieldDriverPhone = 'driverPhone';
  static const String fieldDriverName = 'driverName';
}
