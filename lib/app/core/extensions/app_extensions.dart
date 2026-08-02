import 'package:flutter/material.dart';

/// Useful String extensions.
extension StringExtensions on String {
  /// Capitalizes the first letter of the string.
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Formats raw 10-digit phone string to +91 XXXXX XXXXX format.
  String toFormattedPhone() {
    final clean = replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    }
    return this;
  }

  /// Truncates string with ellipsis if longer than [maxLength].
  String truncateTo(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}

/// Useful BuildContext extensions for UI components.
extension BuildContextExtensions on BuildContext {
  /// Returns theme data.
  ThemeData get theme => Theme.of(this);

  /// Returns text theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Returns true if current theme brightness is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Returns screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Returns screen height.
  double get screenHeight => MediaQuery.of(this).size.height;
}
