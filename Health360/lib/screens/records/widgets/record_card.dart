import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/health_record.dart';
import '../../../widgets/h360_card.dart';

/// One tappable card in the Records list: icon, title, doctor or test name,
/// date, and a "View" link. Used for both consultations and lab results.
class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record, required this.onTap});

  final HealthRecord record;

  /// Called when the card is tapped (the screen decides which detail page opens).
  final VoidCallback onTap;

  /// A clipboard for lab results, a medical bag for consultations.
  IconData get _icon => record.type == RecordType.labResult
      ? Icons.assignment_outlined
      : Icons.medical_services_outlined;

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Title, subtitle, date and "View" link
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  record.subtitle,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                Text(
                  formatLongDate(record.date),
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
