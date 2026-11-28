import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';
import '../../../widgets/advisory_banner.dart';
import '../../../widgets/horizontal_scroll_fade.dart';

/// Dismissible non-diagnostic advisory banner or persistent underlined link.
class TodayAdvisorySection extends StatelessWidget {
  /// Creates a [TodayAdvisorySection].
  const TodayAdvisorySection({
    super.key,
    required this.advisorySeen,
    required this.onDismiss,
    required this.onShowDialog,
  });

  /// Whether the caregiver has minimized the full advisory banner.
  final bool advisorySeen;

  /// Callback invoked when the caregiver dismisses the banner.
  final VoidCallback onDismiss;

  /// Callback invoked when the caregiver reopens the full advisory dialog.
  final VoidCallback onShowDialog;

  @override
  Widget build(BuildContext context) {
    if (!advisorySeen) {
      return AdvisoryBanner(
        dismissTooltip: 'Dismiss advisory',
        onDismiss: onDismiss,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onShowDialog,
        icon: const Icon(
          Icons.info_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        label: Text(
          'Not a diagnostic tool',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// Empty plan card displayed when no activities are scheduled for today.
class TodayEmptyPlanCard extends StatelessWidget {
  /// Creates a [TodayEmptyPlanCard].
  const TodayEmptyPlanCard({super.key, required this.onFindIdea});

  /// Callback invoked when the caregiver taps "Find an idea".
  final VoidCallback onFindIdea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.today_outlined,
                size: 20,
                color: AppColors.forest,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  'No activities planned for today',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Want a quick idea? Most take 10 minutes or less.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          OutlinedButton(
            onPressed: onFindIdea,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.touchTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
            ),
            child: const Text('Find an idea'),
          ),
        ],
      ),
    );
  }
}

/// Summary section showing completed activity counts for today.
class TodayHistorySection extends StatelessWidget {
  /// Creates a [TodayHistorySection].
  const TodayHistorySection({
    super.key,
    required this.childName,
    required this.completedCount,
  });

  /// Active child's display nickname.
  final String childName;

  /// Number of activities marked complete today.
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryText = completedCount == 0
        ? 'Completed activities for $childName will show here.'
        : completedCount == 1
        ? '1 activity completed for $childName today.'
        : '$completedCount activities completed for $childName today.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          summaryText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Horizontal row of quick filter chips for duration, materials, and setting.
class TodayQuickFilterChips extends StatelessWidget {
  /// Creates a [TodayQuickFilterChips] row.
  const TodayQuickFilterChips({
    super.key,
    required this.under10Mins,
    required this.noMaterials,
    required this.selectedSetting,
    required this.onUnder10MinsChanged,
    required this.onNoMaterialsChanged,
    required this.onSettingChanged,
  });

  /// Whether the "Under 10 mins" chip is selected.
  final bool under10Mins;

  /// Whether the "No materials needed" chip is selected.
  final bool noMaterials;

  /// Currently selected play setting filter (`indoor` or `outdoor`), or `null`.
  final String? selectedSetting;

  /// Callback invoked when the duration filter changes.
  final ValueChanged<bool> onUnder10MinsChanged;

  /// Callback invoked when the materials filter changes.
  final ValueChanged<bool> onNoMaterialsChanged;

  /// Callback invoked when the indoor or outdoor setting filter changes.
  final ValueChanged<String?> onSettingChanged;

  @override
  Widget build(BuildContext context) {
    return HorizontalScrollFade(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(right: AppSpacing.space16),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Under 10 mins'),
              selected: under10Mins,
              onSelected: onUnder10MinsChanged,
            ),
            const SizedBox(width: AppSpacing.space8),
            FilterChip(
              label: const Text('No materials needed'),
              selected: noMaterials,
              onSelected: onNoMaterialsChanged,
            ),
            ...PlaySetting.filterLabels.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.space8),
                child: FilterChip(
                  label: Text(entry.value),
                  selected: selectedSetting == entry.key,
                  onSelected: (selected) =>
                      onSettingChanged(selected ? entry.key : null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state displayed when active quick filters hide every planned activity.
class TodayEmptyFilterState extends StatelessWidget {
  /// Creates a [TodayEmptyFilterState].
  const TodayEmptyFilterState({super.key, required this.onClearFilters});

  /// Callback invoked when the caregiver taps "Clear filters".
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.filter_list_off,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.space16),
          Text(
            'No activities match your filters',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Try clearing one or more filters to see planned activities.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space16),
          FilledButton.tonal(
            onPressed: onClearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}
