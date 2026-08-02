import 'package:flutter/material.dart';

/// Centralizes platform date-picker invocation without owning feature state.
class AppDatePicker {
  AppDatePicker._();

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) =>
      showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );
}
