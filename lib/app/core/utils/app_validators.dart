/// Centralized, reusable form field validators for the application.
class AppValidators {
  AppValidators._();

  /// Validates standard 10-digit Indian mobile numbers.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  /// Validates email address format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter email address';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password minimum length (6+ chars).
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validates Indian commercial vehicle registration numbers (e.g., GJ01-SA-1114).
  static String? validateVehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter vehicle registration number';
    }
    final clean = value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    final vehicleRegex = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{1,2}\d{4}$');
    if (!vehicleRegex.hasMatch(clean)) {
      return 'Invalid vehicle number format (e.g. GJ01-SA-1114)';
    }
    return null;
  }

  /// Validates required non-empty string fields.
  static String? validateRequired(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates numeric fields (integers or doubles).
  static String? validateNumeric(String? value, {String fieldName = 'Value'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number';
    }
    return null;
  }
}
