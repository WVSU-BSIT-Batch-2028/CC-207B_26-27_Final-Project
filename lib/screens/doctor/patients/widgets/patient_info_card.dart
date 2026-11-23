import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../widgets/h360_card.dart';

/// A card with an icon tile, a bold label and a value underneath, e.g.
/// "Allergies" / "None". Used on the Patient Details screen.
class PatientInfoCard extends StatelessWidget {
  const PatientInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;

  /// Bold heading, e.g. "Medical Conditions".
  final String label;

  /// The text under the heading, e.g. "Common Cold".
  final String value;

  @override
  Widget build(BuildContext context) {
    return H360Card(
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
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),

          // Label and value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
