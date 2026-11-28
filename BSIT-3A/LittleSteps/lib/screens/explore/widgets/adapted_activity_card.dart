import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../theme/app_tokens.dart';
import 'activity_materials_wrap.dart';

/// Card presenting the adapted play variation, safety note, and scheduling actions.
class AdaptedActivityCard extends StatelessWidget {
  /// Creates an [AdaptedActivityCard] for [response].
  const AdaptedActivityCard({
    super.key,
    required this.response,
    required this.isScheduling,
    required this.onTryAnother,
    this.onAddAdapted,
  });

  /// Adaptation payload returned by the backend AI service.
  final AdaptActivityResponse response;

  /// Whether scheduling the adapted activity is currently in flight.
  final bool isScheduling;

  /// Callback invoked to re-open adjustment options and pick another variation.
  final VoidCallback onTryAnother;

  /// Optional callback scheduling the adapted activity onto Today's plan.
  final VoidCallback? onAddAdapted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adapted = response.adapted;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space12),
      child: Card.outlined(
        color: AppColors.surfaceCard,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Adapted variation',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Chip(
                    label: Text(
                      response.isAiGenerated
                          ? (response.badge ?? 'Suggested by AI')
                          : 'Our adjustment',
                    ),
                    backgroundColor: AppColors.softGreen,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(adapted.adaptedTitle, style: theme.textTheme.titleMedium),
              if (adapted.explanation.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.space12),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Text(
                    'Why it works: ${adapted.explanation}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
              if (adapted.safetyNotice.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      child: Text(
                        adapted.safetyNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.space12),
              Text('Materials', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.space4),
              MaterialPillsWrap(materials: adapted.materials),
              const SizedBox(height: AppSpacing.space12),
              Text('Adjusted steps', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.space4),
              NumberedStepsList(
                steps: adapted.instructions,
                textStyle: theme.textTheme.bodySmall,
              ),
              Text(
                'Everyday play idea only — not a medical or developmental test.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space8,
                children: [
                  if (onAddAdapted != null)
                    FilledButton.icon(
                      onPressed: isScheduling ? null : onAddAdapted,
                      icon: const Icon(Icons.add),
                      label: const Text('Add adapted activity to plan'),
                    ),
                  OutlinedButton(
                    onPressed: onTryAnother,
                    child: const Text('Try another adjustment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
