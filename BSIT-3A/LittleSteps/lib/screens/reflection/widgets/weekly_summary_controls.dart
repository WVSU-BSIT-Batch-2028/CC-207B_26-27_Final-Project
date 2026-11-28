import 'package:flutter/material.dart';

import '../../../models/summary.dart';
import '../../../theme/app_tokens.dart';

/// Soft-green child context badge displayed at the top of the weekly summary.
class WeeklySummaryChildBadge extends StatelessWidget {
  /// Creates a [WeeklySummaryChildBadge].
  const WeeklySummaryChildBadge({
    super.key,
    required this.childName,
    required this.childAgeDisplay,
  });

  /// Active child's nickname.
  final String childName;

  /// Formatted age label for the active child.
  final String childAgeDisplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space8,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.child_care_outlined,
            size: 16,
            color: AppColors.forest,
          ),
          const SizedBox(width: AppSpacing.space8),
          Text(
            'For $childName · $childAgeDisplay',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable week-range selector displaying the active Monday-to-Sunday window.
class WeekSelectorCard extends StatelessWidget {
  /// Creates a [WeekSelectorCard].
  const WeekSelectorCard({super.key, required this.label, required this.onTap});

  /// Formatted week label shown inside the selector.
  final String label;

  /// Callback invoked when the caregiver opens the week picker sheet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week · Monday to Sunday',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4 / 2),
            Row(
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                const Spacer(),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet allowing caregivers to switch between recorded weeks.
class WeekPickerSheet extends StatelessWidget {
  /// Creates a [WeekPickerSheet].
  const WeekPickerSheet({
    super.key,
    required this.summaries,
    required this.selectedWeekId,
    required this.onSelected,
  });

  /// Map of available [WeeklySummary] entries keyed by ISO week identifier.
  final Map<String, WeeklySummary> summaries;

  /// Currently selected ISO week identifier.
  final String selectedWeekId;

  /// Callback invoked with the newly picked ISO week identifier.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a week',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            ...summaries.entries.map((entry) {
              final weekId = entry.key;
              final summary = entry.value;
              final isSelected = weekId == selectedWeekId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space8,
                  vertical: AppSpacing.space4,
                ),
                title: Text(
                  summary.formattedRange,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.forest
                        : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  summary.isEmptyWeek
                      ? 'No activities recorded'
                      : '${summary.completedActivityCount} activities · ${summary.observedMilestoneCount} milestones',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.forest)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(weekId);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
