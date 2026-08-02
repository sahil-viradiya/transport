/// Strongly-typed Failure classes for domain layer error handling.
abstract class AppFailure implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const AppFailure(this.message, {this.code, this.cause});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Returned when server or Firestore API operations fail.
class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {super.code, super.cause});
}

/// Returned when internet connection or network transport fails.
class NetworkFailure extends AppFailure {
  const NetworkFailure({String message = 'Network connection unavailable'})
      : super(message);
}

/// Returned when user authentication or authorization fails.
class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code, super.cause});
}

/// Returned when form validation or data contract verification fails.
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code});
}

/// Returned when local storage / SharedPreferences read/write fails.
class CacheFailure extends AppFailure {
  const CacheFailure(super.message, {super.code, super.cause});
}
