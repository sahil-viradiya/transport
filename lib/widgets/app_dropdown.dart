import 'package:flutter/material.dart';

/// Form dropdown with the app's standard border and label treatment.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.labelText,
    this.hintText,
    this.validator,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? labelText;
  final String? hintText;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(labelText: labelText, hintText: hintText),
      );
}
