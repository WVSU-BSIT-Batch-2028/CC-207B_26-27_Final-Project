import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';

/// Card presenting an AI-recommended or catalog-fallback play idea.
class AiSuggestionCard extends StatelessWidget {
  /// Creates an [AiSuggestionCard].
  const AiSuggestionCard({
    super.key,
    required this.suggestion,
    required this.settingLabel,
    required this.hasActiveChild,
    required this.alreadyAdded,
    required this.onAddToPlan,
  });

  /// Play recommendation data returned by the AI or catalog service.
  final Recommendation suggestion;

  /// Caregiver-facing play setting label (for example, `Indoor`).
  final String settingLabel;

  /// Whether an active child profile is selected for adding to a plan.
  final bool hasActiveChild;

  /// Whether this activity has already been added to today's plan.
  final bool alreadyAdded;

  /// Callback invoked when the caregiver taps "Add to today's plan".
  final VoidCallback onAddToPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = suggestion.activity;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.space16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity != null)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCanvas,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      formalDomainLabel(activity.domain),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${activity.durationEstimate} · $settingLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (suggestion.isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space8,
                        vertical: AppSpacing.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAdvisory,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(color: AppColors.borderAdvisory),
                      ),
                      child: Text(
                        'Material adaptation',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              suggestion.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space12),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      'Why this fits: ${suggestion.whyPicked}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            if (activity != null) ...[
              if (activity.materials.isNotEmpty) ...[
                Text(
                  'Materials needed:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  activity.materials.join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
              ],
              if (activity.instructions.isNotEmpty) ...[
                Text(
                  'Steps to play:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                ...activity.instructions.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.space12),
              ],
            ],
            if (suggestion.isCustom &&
                activity != null &&
                activity.limitations.isNotEmpty) ...[
              Text(
                'Safety note: ${activity.limitations}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
            ],
            if (!hasActiveChild)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                child: Text(
                  'Choose a child to add this to a plan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: (!hasActiveChild || alreadyAdded)
                    ? null
                    : onAddToPlan,
                icon: Icon(alreadyAdded ? Icons.check : Icons.add, size: 18),
                label: Text(
                  alreadyAdded
                      ? "Added to today's plan"
                      : "Add to today's plan",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
