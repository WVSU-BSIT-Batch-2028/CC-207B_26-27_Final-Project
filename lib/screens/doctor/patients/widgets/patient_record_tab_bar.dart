import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

/// The three pills at the top of the Patient Records screens.
enum PatientRecordTab {
  records('Records'),
  labResults('Lab Results'),
  prescriptions('Prescriptions');

  const PatientRecordTab(this.label);

  /// Text shown on the pill.
  final String label;
}

/// Row of pills (Records / Lab Results / Prescriptions).
///
/// The selected pill is filled navy with white text and a check mark; the
/// others are outlined. A [Wrap] is used so the pills move to a second line
/// instead of overflowing when the text size is Large or Extra large.
class PatientRecordTabBar extends StatelessWidget {
  const PatientRecordTabBar(
      {super.key, required this.selected, required this.onChanged});

  /// The tab that is currently active.
  final PatientRecordTab selected;

  /// Called with the new tab when the doctor taps a pill.
  final ValueChanged<PatientRecordTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tab in PatientRecordTab.values)
          ChoiceChip(
            label: Text(tab.label),
            selected: tab == selected,
            onSelected: (_) => onChanged(tab),
            selectedColor: AppColors.brandNavy,
            backgroundColor: AppColors.surface,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: tab == selected ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            side: BorderSide(
                color:
                    tab == selected ? AppColors.brandNavy : AppColors.border),
          ),
      ],
    );
  }
}
