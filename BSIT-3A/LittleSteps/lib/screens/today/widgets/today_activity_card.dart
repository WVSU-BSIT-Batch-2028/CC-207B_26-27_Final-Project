import 'package:flutter/material.dart';

import '../../../models/activity.dart';
import '../../../models/plan.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';

/// Card displaying a scheduled play activity on the Today screen.
class TodayActivityCard extends StatelessWidget {
  /// Creates a [TodayActivityCard].
  const TodayActivityCard({
    super.key,
    required this.plan,
    required this.activity,
    required this.onCompleteToggle,
  });

  /// Scheduled plan item tracking completion state and custom activity metadata.
  final PlanItem plan;

  /// Resolved catalog or custom play activity details.
  final Activity activity;

  /// Callback invoked when the caregiver toggles activity completion.
  final VoidCallback onCompleteToggle;

  String _formatDomain(String domain) => formalDomainLabel(domain);

  String _formatSetting(String setting) => formatSettingLabel(setting);

  void _showActivityDetails(BuildContext context) {
    final theme = Theme.of(context);
    final sourceLabel = plan.customActivity?.sourceLabel;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: AppSizes.sheetMaxWidth),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space24,
            AppSpacing.space8,
            AppSpacing.space24,
            AppSpacing.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sourceLabel != null && sourceLabel.isNotEmpty) ...[
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
                    sourceLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
              ],
              Text(
                activity.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space4,
                children: [
                  ActivityTagBadge(label: _formatDomain(activity.domain)),
                  ActivityTagBadge(label: '${activity.durationMinutes} mins'),
                  ActivityTagBadge(label: _formatSetting(activity.setting)),
                ],
              ),
              if (activity.materials.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space16),
                Text(
                  'Materials needed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  activity.materials.join(', '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (activity.instructions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space16),
                Text(
                  'Steps to play',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                ...activity.instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (activity.limitations.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAdvisory,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.borderAdvisory),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.artworkForest,
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          activity.limitations,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (activity.provenanceSource.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space12),
                Text(
                  'Source: ${activity.provenanceSource}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = plan.isCompleted;
    final hasDetails = activity.instructions.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      color: AppColors.surfaceCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: hasDetails ? () => _showActivityDetails(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        Wrap(
                          spacing: AppSpacing.space8,
                          runSpacing: AppSpacing.space4,
                          children: [
                            ActivityTagBadge(
                              label: _formatDomain(activity.domain),
                            ),
                            ActivityTagBadge(
                              label: '${activity.durationMinutes} mins',
                            ),
                            ActivityTagBadge(
                              label: _formatSetting(activity.setting),
                            ),
                            if (activity.materials.isEmpty ||
                                activity.materials.every(
                                  (m) => m.toLowerCase() == 'none',
                                ))
                              const ActivityTagBadge(label: 'No materials')
                            else
                              ActivityTagBadge(
                                label:
                                    '${activity.materials.length} ${activity.materials.length == 1 ? 'material' : 'materials'}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  _buildCompletionAction(context),
                ],
              ),
              if (isCompleted) ...[
                const SizedBox(height: AppSpacing.space12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12,
                    vertical: AppSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: AppColors.forest.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.forest,
                      ),
                      const SizedBox(width: AppSpacing.space4),
                      Text(
                        'Completed today',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Renders the accessible 48x48dp completion button or toggle indicator.
  Widget _buildCompletionAction(BuildContext context) {
    if (plan.isCompleted) {
      return Semantics(
        label: 'Marked complete. Tapping will toggle status.',
        child: IconButton(
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.forest,
            size: 28,
          ),
          tooltip: 'Completed today',
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          onPressed: onCompleteToggle,
        ),
      );
    }

    return Semantics(
      label: 'Mark ${activity.title} complete',
      child: OutlinedButton(
        onPressed: onCompleteToggle,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
          side: const BorderSide(color: AppColors.forest),
        ),
        child: const Text('Mark complete'),
      ),
    );
  }
}

/// Pill badge displaying a concise activity metadata tag.
class ActivityTagBadge extends StatelessWidget {
  /// Creates an [ActivityTagBadge].
  const ActivityTagBadge({super.key, required this.label});

  /// Metadata text displayed inside the pill.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
