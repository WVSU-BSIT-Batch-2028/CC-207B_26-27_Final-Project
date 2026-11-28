import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/book.dart';
import '../../theme/app_tokens.dart';
import '../../utils/domain_labels.dart';

/// Dialog presenting a storybook play idea with an option to add it to today's
/// plan.
class PlayCompanionDialog extends StatelessWidget {
  /// Creates a [PlayCompanionDialog].
  const PlayCompanionDialog({
    super.key,
    required this.book,
    required this.ideaTitle,
    required this.domain,
    required this.instructions,
    required this.safetyNotice,
    this.badge = 'Suggested by AI',
    this.onAddToPlan,
    this.isAdding = false,
  });

  /// Storybook associated with the suggested play companion activity.
  final BookItem book;

  /// Title of the suggested play activity.
  final String ideaTitle;

  /// Developmental domain key for the activity.
  final String domain;

  /// Step-by-step play guidance linked to [book].
  final String instructions;

  /// Supervision or safety reminder displayed with the play idea.
  final String safetyNotice;

  /// Optional provenance badge shown next to the activity title.
  final String? badge;

  /// Callback invoked when the caregiver adds the play idea to today's plan.
  final VoidCallback? onAddToPlan;

  /// Whether the add-to-plan request is currently in progress.
  final bool isAdding;

  /// Maps a backend [domain] key to its caregiver-facing label.
  static String domainLabel(String domain) => friendlyDomainLabel(domain);

  /// Builds an [Activity] from this play idea so it can be added to a plan.
  Activity toActivity({String? childNickname}) {
    final sanitizedId =
        'story-${book.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-')}';
    return Activity(
      id: sanitizedId,
      title: ideaTitle,
      type: 'story',
      language: AppLanguages.english,
      setting: PlaySetting.indoor,
      ageBand: 'all',
      domain: domain,
      durationMinutes: 10,
      durationEstimate: '10 mins',
      materials: [book.title, 'Everyday household toys'],
      instructions: [
        'Read through "${book.title}" together at an unhurried pace.',
        instructions,
        'Talk about what happens in the pictures and celebrate every effort.',
      ],
      provenanceSource: '',
      status: Activity.statusCustomSnapshot,
      limitations: safetyNotice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      backgroundColor: AppColors.surfaceCard,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space8,
                              vertical: AppSpacing.space4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: AppColors.forest,
                                ),
                                const SizedBox(width: AppSpacing.space4),
                                Text(
                                  badge!,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                        ],
                        Text(
                          ideaTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close dialog',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4 / 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCanvas,
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      domainLabel(domain),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      'Companion to ${book.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCanvas,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to play together:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      instructions,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAdvisory.withAlpha(80),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.warning.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: AppColors.artworkForest,
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      child: Text(
                        safetyNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space24),
              Row(
                children: [
                  Flexible(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSizes.touchTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space8,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Flexible(
                    flex: 2,
                    child: FilledButton(
                      onPressed: isAdding ? null : onAddToPlan,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSizes.touchTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space8,
                        ),
                      ),
                      child: isAdding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surfaceCard,
                              ),
                            )
                          : const Text(
                              "Add to today's plan",
                              maxLines: 1,
                              softWrap: false,
                            ),
                    ),
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
