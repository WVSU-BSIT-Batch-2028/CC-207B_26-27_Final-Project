import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/state_views.dart';

/// Empty-state card displayed when no activities or observations exist in a week.
class WeeklySummaryEmptyCard extends StatelessWidget {
  /// Creates a [WeeklySummaryEmptyCard].
  const WeeklySummaryEmptyCard({super.key, required this.onFindIdea});

  /// Callback invoked when the caregiver taps "Find a 10-minute idea".
  final VoidCallback onFindIdea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.cream,
            radius: 28,
            child: Icon(
              Icons.bar_chart_outlined,
              color: AppColors.forest,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          Text(
            'Nothing recorded this week yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            "This fills in when you finish an activity or note a milestone. There's no daily goal and nothing to catch up on.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space20),
          SizedBox(
            height: AppSizes.touchTarget,
            child: FilledButton(
              onPressed: onFindIdea,
              child: const Text('Find a 10-minute idea'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading placeholder for the weekly reflection summary.
class WeeklySummaryLoadingView extends StatelessWidget {
  /// Creates a [WeeklySummaryLoadingView].
  const WeeklySummaryLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Container(
              height: 90,
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(
                              AppRadius.skeleton,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        Container(
                          width: 160,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.skeleton,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Recoverable error card shown when loading a weekly summary fails.
class WeeklySummaryErrorCard extends StatelessWidget {
  /// Creates a [WeeklySummaryErrorCard].
  const WeeklySummaryErrorCard({super.key, required this.onRetry});

  /// Callback invoked when the caregiver taps Retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InlineErrorCard(onRetry: onRetry);
  }
}

/// Offline banner displayed when cached weekly summaries are shown.
class WeeklySummaryOfflineBanner extends StatelessWidget {
  /// Creates a [WeeklySummaryOfflineBanner].
  const WeeklySummaryOfflineBanner({super.key, required this.onRetry});

  /// Callback invoked when the caregiver taps Retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OfflineStatusCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      message: 'Showing previously recorded moments. Connect to the internet to sync updates.',
      onRetry: onRetry,
    );
  }
}
