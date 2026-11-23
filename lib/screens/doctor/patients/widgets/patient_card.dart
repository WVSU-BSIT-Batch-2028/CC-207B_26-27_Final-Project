import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../models/patient.dart';
import '../../../../widgets/h360_card.dart';

/// One tappable card in the Patients list: avatar, name, condition,
/// last visit date and an arrow.
class PatientCard extends StatelessWidget {
  const PatientCard({super.key, required this.patient, required this.onTap});

  final Patient patient;

  /// Called when the card is tapped (the screen decides what opens).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar tile on the left
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name, condition and last visit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  patient.condition,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  patient.lastVisit == null
                      ? 'No visits yet'
                      : 'Last visit: ${formatLongDate(patient.lastVisit!)}',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Arrow at the top right, as in the prototype
          Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.primary),
        ],
      ),
    );
  }
}
