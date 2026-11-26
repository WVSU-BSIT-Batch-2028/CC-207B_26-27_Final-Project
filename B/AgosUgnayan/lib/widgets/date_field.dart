// A form field that opens a calendar when tapped, e.g. "Harvest date" or
// "Needed by". It shows the picked date and can be required or optional.

import 'package:flutter/material.dart';

import '../utils/format.dart';
import '../utils/strings.dart';

/// Read-only text field + date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    this.isRequired = true,
    this.notBeforeToday = false,
  });

  /// Label inside the box. Use null when a LabeledField shows it above.
  final String? label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate; // earliest date the user may pick
  final bool isRequired;

  /// True refuses dates before today (e.g. "Needed by").
  final bool notBeforeToday;

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    // The calendar must open on a date it allows, so fall back to today.
    final start = value != null && value!.isAfter(firstDate) ? value! : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      // A new key when the date changes makes the field show the new text.
      key: ValueKey(value),
      initialValue: value == null ? '' : formatDate(value!),
      readOnly: true, // typing is not allowed, only picking
      onTap: () => _pickDate(context),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value != null && !isRequired
            ? IconButton(
                tooltip: 'Clear date',
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today),
      ),
      validator: (_) {
        if (isRequired && value == null) return AppStrings.dateRequired;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (notBeforeToday && value != null && value!.isBefore(today)) {
          return 'Choose today or a later date.';
        }
        return null;
      },
    );
  }
}
