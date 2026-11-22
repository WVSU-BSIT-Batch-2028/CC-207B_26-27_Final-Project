import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/date_format.dart';
import '../models/taken_history.dart';
import 'prescription_info_card.dart';

/// "Doses taken" card: a summary line plus the most recent days.
///
/// Shows the "Mark as Taken" history (HCI feedback) on the History Details
/// screen.
class TakenHistoryCard extends StatelessWidget {
  const TakenHistoryCard({
    super.key,
    required this.history,
    required this.courseDays,
    this.maxShown = 5,
  });

  /// The days a dose was marked as taken.
  final TakenHistory history;

  /// Length of the whole course in days (the "of Y" in "X of Y days").
  final int courseDays;

  /// How many recent days to list before showing "+ N earlier days".
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final recent = history.recent(maxShown);
    final hidden = history.takenCount - recent.length;

    return PrescriptionInfoCard(
      icon: Icons.fact_check_outlined,
      children: [
        Text(
          'Doses taken',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Empty case: nothing was ever marked as taken.
        if (history.takenCount == 0)
          Text(
            'No doses were marked as taken.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          )
        else ...[
          Text(
            'Taken on ${history.takenCount} of $courseDays days',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),

          // One row per recent day: icon AND text, never colour alone.
          for (final day in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      formatLongDate(day),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (hidden > 0)
            Text(
              '+ $hidden earlier ${hidden == 1 ? 'day' : 'days'}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ],
    );
  }
}
