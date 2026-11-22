import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../models/patient_lab_result.dart';
import '../../../../widgets/h360_card.dart';

/// One tappable card in a patient's lab results list: icon, test name,
/// date and an arrow.
class PatientLabCard extends StatelessWidget {
  const PatientLabCard({super.key, required this.result, required this.onTap});

  final PatientLabResult result;

  /// Called when the card is tapped (the screen decides what opens).
  final VoidCallback onTap;

  /// A drop for blood tests, a flask for urine tests, a clipboard for the rest.
  IconData get _icon {
    final name = result.testName.toLowerCase();
    if (name.contains('blood')) return Icons.water_drop_outlined;
    if (name.contains('urin')) return Icons.science_outlined;
    return Icons.assignment_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Row(
        children: [
          // Icon tile on the left
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),

          // Test name and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.testName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatLongDate(result.date),
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Arrow on the right, as in the prototype
          Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.primary),
        ],
      ),
    );
  }
}
