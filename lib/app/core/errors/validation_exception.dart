/// Exception thrown when a business logic validation rule fails
/// (e.g. duplicate truck number, duplicate trip assignment, driver on leave).
class ValidationException implements Exception {
  final String message;
  final String? code;

  ValidationException(this.message, {this.code});

  @override
  String toString() => message;
}
