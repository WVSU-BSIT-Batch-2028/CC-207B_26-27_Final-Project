import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../theme/app_tokens.dart';

/// Summary banner for multi-activity play blocks with a batch add-to-plan CTA.
class AiPlayBlockBanner extends StatelessWidget {
  /// Creates an [AiPlayBlockBanner].
  const AiPlayBlockBanner({
    super.key,
    required this.suggestions,
    required this.timeMinutes,
    required this.hasActiveChild,
    required this.allAdded,
    required this.isAddingAll,
    required this.onAddAll,
  });

  /// Recommended play activities grouped into the current play block.
  final List<Recommendation> suggestions;

  /// Caregiver's requested total play window in minutes.
  final int timeMinutes;

  /// Whether an active child profile is selected for plan saving.
  final bool hasActiveChild;

  /// Whether every recommendation in [suggestions] is already added to today.
  final bool allAdded;

  /// Whether a batch add-to-plan request is currently in flight.
  final bool isAddingAll;

  /// Callback invoked when the caregiver taps "Add all to today's plan".
  final VoidCallback onAddAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = suggestions.fold<int>(
      0,
      (sum, item) => sum + (item.activity?.durationMinutes ?? 10),
    );
    final count = suggestions.length;
    final hasCustom = suggestions.any((item) => item.isCustom);
    final itemLabel = hasCustom
        ? (count == 1 ? 'play idea' : 'play ideas')
        : (count == 1 ? 'reviewed activity' : 'reviewed activities');
    final pacingSummary = totalMinutes < timeMinutes
        ? '$count short $itemLabel '
              '(~$totalMinutes mins total) · repeat favorites or mix in free '
              'play to fill $timeMinutes min.'
        : '$count short $itemLabel '
              '(~$totalMinutes mins total) paced for young attention spans.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.softGreen.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 18,
                color: AppColors.forest,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  'Play block for $timeMinutes min',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            pacingSummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (suggestions.length >= 2 && hasActiveChild) ...[
            const SizedBox(height: AppSpacing.space12),
            OutlinedButton.icon(
              onPressed: (allAdded || isAddingAll) ? null : onAddAll,
              icon: Icon(allAdded ? Icons.check : Icons.playlist_add, size: 18),
              label: Text(
                allAdded
                    ? "All added to today's plan"
                    : "Add all to today's plan",
              ),
            ),
          ],
        ],
      ),
    );
  }
}
