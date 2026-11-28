import 'package:flutter/material.dart';

import '../../../models/age_band.dart';
import '../../../models/child.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/state_views.dart';

/// Banner indicating that profile changes require an active connection.
class ChildOfflineNotice extends StatelessWidget {
  /// Creates a [ChildOfflineNotice].
  ///
  /// Renders a retry action when [onRetry] is provided.
  const ChildOfflineNotice({super.key, this.onRetry});

  /// Optional callback invoked when the caregiver taps "Try again".
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return OfflineStatusCard(
      message: 'Reconnect to save changes.',
      retryLabel: 'Try again',
      onRetry: onRetry,
    );
  }
}

/// Interactive card displaying a child profile with switch and edit actions.
class ChildProfileCard extends StatelessWidget {
  /// Creates a [ChildProfileCard].
  const ChildProfileCard({
    super.key,
    required this.child,
    required this.isCurrent,
    required this.onSelect,
    required this.onEdit,
  });

  /// Child profile rendered in this card.
  final Child child;

  /// Whether [child] is currently selected as the active child.
  final bool isCurrent;

  /// Callback invoked when the caregiver taps to switch to [child].
  final VoidCallback onSelect;

  /// Callback invoked when the caregiver taps the edit button.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bandLabel = ageBandForCode(child.ageBand)?.label ?? child.ageBand;

    return Semantics(
      selected: isCurrent,
      hint: isCurrent
          ? 'Current active child'
          : 'Switches active child to ${child.nickname}',
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.space12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isCurrent ? AppColors.forest : AppColors.borderSubtle,
            width: isCurrent ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: isCurrent ? null : onSelect,
          hoverColor: AppColors.softGreen.withValues(alpha: 0.35),
          splashColor: AppColors.softGreen.withValues(alpha: 0.6),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.softGreen,
                      child: Text(
                        child.nickname.isNotEmpty
                            ? child.nickname[0].toUpperCase()
                            : 'C',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.nickname,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            bandLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit ${child.nickname}',
                      onPressed: onEdit,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                Align(
                  alignment: Alignment.centerRight,
                  child: isCurrent
                      ? const _CurrentChildBadge()
                      : Text(
                          'Tap to switch',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Informational card explaining data minimization for child profiles.
class ChildPrivacyHintCard extends StatelessWidget {
  /// Creates a [ChildPrivacyHintCard].
  const ChildPrivacyHintCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            'Just enough to make ideas relevant',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'We only keep a nickname and an age range or birth month. '
            'No full birthdays, surnames or photos are required.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentChildBadge extends StatelessWidget {
  const _CurrentChildBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: AppColors.forest),
          const SizedBox(width: AppSpacing.space4),
          Text(
            'Current child',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
