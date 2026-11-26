// A dropdown for picking one item from a fixed list (crop, unit, town), with
// the same look and validation as our text fields.

import 'package:flutter/material.dart';

import '../utils/strings.dart';

/// Dropdown that shows "Please choose one." when nothing is picked.
class DropdownField extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  /// Label inside the box. Use null when a LabeledField shows it above.
  final String? label;

  /// Grey text shown while nothing is picked, e.g. "Choose a crop".
  final String? hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // A new key when the value changes from outside (e.g. the AI filled it)
      // makes the dropdown show the new value.
      key: ValueKey(value),
      initialValue: value,
      decoration: InputDecoration(labelText: label, hintText: hint),
      isExpanded: true,
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
      validator: (selected) =>
          selected == null ? AppStrings.selectRequired : null,
    );
  }
}
