import 'package:flutter/material.dart';

import '../../../config/external_links.dart';
import '../../../models/activity.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';
import '../../../utils/url_helper.dart';
import 'activity_materials_wrap.dart';

/// Card displaying a catalog play activity with provenance badge, adapt action, and add CTA.
class ExploreActivityCard extends StatelessWidget {
  /// Creates an [ExploreActivityCard].
  const ExploreActivityCard({
    super.key,
    required this.activity,
    required this.domainLabel,
    required this.onAdd,
    this.onAdapt,
    this.onTap,
  });

  /// Catalog activity to render.
  final Activity activity;

  /// Caregiver-friendly developmental domain label (for example, `Thinking`).
  final String domainLabel;

  /// Callback invoked when the caregiver taps "Add to today's plan".
  final VoidCallback onAdd;

  /// Optional callback invoked when the caregiver taps "Adapt activity".
  final VoidCallback? onAdapt;

  /// Optional callback invoked when the caregiver opens the activity detail screen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReviewed = activity.status == Activity.statusReviewedApproved;
    final setting = formatSettingLabel(activity.setting);
    final meta = '${activity.durationEstimate} · $domainLabel · $setting';

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideCard =
              constraints.maxWidth >= AppSizes.wideCardBreakpoint;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: EdgeInsets.all(
                isWideCard ? AppSpacing.space20 : AppSpacing.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 112,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/catalog_cover.png',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: '',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text(activity.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    activity.instructions.join(' '),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  MaterialPillsWrap(materials: activity.materials),
                  const SizedBox(height: AppSpacing.space12),
                  ReviewProvenanceBadge(
                    reviewed: isReviewed,
                    source: activity.provenanceSource,
                    limitations: activity.limitations,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  if (isWideCard)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.space8,
                        runSpacing: AppSpacing.space8,
                        children: [
                          if (onAdapt != null)
                            OutlinedButton.icon(
                              onPressed: onAdapt,
                              icon: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 18,
                              ),
                              label: const Text('Adapt activity'),
                            ),
                          FilledButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add),
                            label: const Text("Add to today's plan"),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (onAdapt != null) ...[
                          OutlinedButton.icon(
                            onPressed: onAdapt,
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                            ),
                            label: const Text('Adapt activity'),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                        ],
                        FilledButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add),
                          label: const Text("Add to today's plan"),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Outlined pill showing a household material needed for an activity.
class MaterialPill extends StatelessWidget {
  /// Creates a [MaterialPill].
  const MaterialPill({super.key, required this.label});

  /// Household material name.
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.space12,
      vertical: AppSpacing.space4,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// Interactive badge displaying an activity's source citation and link modal.
class ReviewProvenanceBadge extends StatelessWidget {
  /// Creates a [ReviewProvenanceBadge].
  const ReviewProvenanceBadge({
    super.key,
    required this.reviewed,
    required this.source,
    required this.limitations,
  });

  /// Whether the item has formal subject-matter approval.
  final bool reviewed;

  /// Curriculum or framework citation string.
  final String source;

  /// Non-diagnostic and safety supervision disclaimer for the activity.
  final String limitations;

  void _showSourceDetails(BuildContext context) {
    final linkInfo = ProvenanceLinkInfo.resolve(source);
    final frameworkTitle = linkInfo.frameworkTitle;
    final sourceUrl = linkInfo.url;
    final buttonLabel = linkInfo.buttonLabel;
    final domainCaption = linkInfo.domainCaption;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => Padding(
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
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.forest,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    'Where this activity comes from',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              frameworkTitle,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (source.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(
                source,
                style: Theme.of(sheetContext).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.space12),
            Text(
              'Adapted from published early childhood play and learning guidelines.',
              style: Theme.of(sheetContext).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (sourceUrl != null && buttonLabel != null) ...[
              const SizedBox(height: AppSpacing.space16),
              SizedBox(
                width: double.infinity,
                height: AppSizes.touchTarget,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    openExternalUrl(context, sourceUrl);
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(buttonLabel),
                ),
              ),
              if (domainCaption != null) ...[
                const SizedBox(height: AppSpacing.space8),
                Center(
                  child: Text(
                    domainCaption,
                    style: Theme.of(sheetContext).textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.space8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = theme.extension<AppStatusColors>()!;
    const subtitle = 'Educational play reference';
    return InkWell(
      onTap: () => _showSourceDetails(context),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: statusColors.infoBackground,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space4 / 2),
              child: Icon(
                reviewed ? Icons.verified_outlined : Icons.menu_book_outlined,
                size: 16,
                color: statusColors.infoForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Semantics(
                label: source.isNotEmpty
                    ? 'Source: $source. $subtitle.'
                    : '$subtitle.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (source.isNotEmpty)
                      Text(
                        'Source: $source',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
