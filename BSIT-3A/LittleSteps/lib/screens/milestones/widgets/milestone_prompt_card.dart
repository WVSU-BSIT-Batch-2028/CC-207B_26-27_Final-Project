import 'package:flutter/material.dart';

import '../../../models/milestone.dart';
import '../../../theme/app_tokens.dart';

/// Card displaying a single developmental milestone prompt and observation status.
class MilestonePromptCard extends StatelessWidget {
  /// Creates a [MilestonePromptCard].
  const MilestonePromptCard({
    super.key,
    required this.prompt,
    required this.observation,
    required this.onTapAction,
  });

  /// Reference observational prompt to display.
  final MilestonePrompt prompt;

  /// Saved caregiver observation for [prompt], if recorded.
  final MilestoneObservation? observation;

  /// Callback invoked when the caregiver taps Add or Update.
  final VoidCallback onTapAction;

  @override
  Widget build(BuildContext context) {
    final isObserved = observation?.isObserved ?? false;
    final notes = observation?.notes;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space16),
        decoration: BoxDecoration(
          color: isObserved ? AppColors.softGreen : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isObserved
                ? AppColors.forest.withValues(alpha: 0.3)
                : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    prompt.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space8),
                SizedBox(
                  height: 36,
                  child: isObserved
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space16,
                            ),
                            side: const BorderSide(color: AppColors.forest),
                            foregroundColor: AppColors.forest,
                          ),
                          onPressed: onTapAction,
                          child: const Text('Update'),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space16,
                            ),
                          ),
                          onPressed: onTapAction,
                          child: const Text('Add'),
                        ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              'Look for: ${prompt.lookFor.join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.space8),
            if (isObserved) ...[
              if (notes != null && notes.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.space8),
                  padding: const EdgeInsets.all(AppSpacing.space8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.note_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.space4),
                      Expanded(
                        child: Text(
                          notes,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              Text(
                'Not seen yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.infoIcon,
                ),
                const SizedBox(width: AppSpacing.space4),
                Expanded(
                  child: Text(
                    prompt.provenance,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
