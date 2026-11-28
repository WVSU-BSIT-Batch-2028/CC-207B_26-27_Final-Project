import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// Summary shortcut cards for weekly reflection and everyday milestone cues.
class TodaySideCards extends StatelessWidget {
  /// Creates a [TodaySideCards] column.
  const TodaySideCards({
    super.key,
    required this.childName,
    required this.milestoneCues,
    this.onOpenReflection,
    this.onOpenMilestones,
  });

  /// Active child's nickname shown in the milestones card subtitle.
  final String childName;

  /// Everyday age-appropriate cues highlighted for the caregiver.
  final List<String> milestoneCues;

  /// Callback invoked when the caregiver taps "View reflection".
  final VoidCallback? onOpenReflection;

  /// Callback invoked when the caregiver taps "View milestones".
  final VoidCallback? onOpenMilestones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodayShortcutCard(
          title: 'This week',
          subtitle:
              'Reflect on everyday moments and shared play from this week.',
          actionLabel: 'View reflection',
          onAction: onOpenReflection,
        ),
        const SizedBox(height: AppSpacing.space16),
        _TodayShortcutCard(
          title: 'Milestones to notice',
          subtitle: milestoneCues.isNotEmpty
              ? 'Everyday cues to notice for $childName:'
              : 'Explore everyday developmental cues to notice for $childName.',
          actionLabel: 'View milestones',
          onAction: onOpenMilestones,
          body: milestoneCues.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: milestoneCues
                      .map(
                        (cue) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.space8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(
                                  top: AppSpacing.space4 / 2,
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                  color: AppColors.forest,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space8),
                              Expanded(
                                child: Text(
                                  cue,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _TodayShortcutCard extends StatelessWidget {
  const _TodayShortcutCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.body,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Widget? body;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.space12),
            body!,
            const SizedBox(height: AppSpacing.space8),
          ] else
            const SizedBox(height: AppSpacing.space16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
