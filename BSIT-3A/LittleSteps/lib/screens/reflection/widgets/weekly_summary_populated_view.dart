import 'package:flutter/material.dart';

import '../../../models/summary.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';
import '../../../widgets/responsive_layout.dart';

/// Populated weekly reflection summary displaying counts, domains, and prompt.
class WeeklySummaryPopulatedView extends StatelessWidget {
  /// Creates a [WeeklySummaryPopulatedView].
  const WeeklySummaryPopulatedView({
    super.key,
    required this.childName,
    required this.summary,
  });

  /// Active child's nickname displayed in summary headers and disclaimers.
  final String childName;

  /// Weekly progress summary to display.
  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryCard = Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week with $childName',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          Row(
            children: [
              Expanded(
                child: _SummaryStatTile(
                  value: '${summary.completedActivityCount}',
                  label: 'activities\ncompleted',
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: _SummaryStatTile(
                  value: '${summary.observedMilestoneCount}',
                  label: summary.observedMilestoneCount == 1
                      ? 'milestone\nnoticed'
                      : 'milestones\nnoticed',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            "Based only on what you wrote down. It's not a test, and it never compares $childName with other children. Journal notes stay private.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );

    final domainsCard = Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everyday play areas',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          ..._buildDomainRows(theme, summary.domainDistribution),
        ],
      ),
    );

    final promptCard = summary.reflectionPrompt.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(AppSpacing.space16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Something to try',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  summary.reflectionPrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  'An idea for play, not a goal to meet.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space24),
      child: AdaptiveTwoPane(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summaryCard,
            const SizedBox(height: AppSpacing.space16),
            domainsCard,
          ],
        ),
        secondary: promptCard,
        verticalSpacing: AppSpacing.space16,
      ),
    );
  }

  List<Widget> _buildDomainRows(
    ThemeData theme,
    Map<String, int> distribution,
  ) {
    return developmentalDomains.map((domain) {
      final count = distribution[domain.$1] ?? 0;
      final countText = count == 0
          ? 'None this week'
          : count == 1
          ? '1 activity'
          : '$count activities';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
        child: Row(
          children: [
            Text(
              domain.$2,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              countText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: count == 0
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
                fontWeight: count == 0 ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _SummaryStatTile extends StatelessWidget {
  const _SummaryStatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: AppSpacing.space4 / 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
