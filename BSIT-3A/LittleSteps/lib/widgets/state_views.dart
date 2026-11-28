import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A loading indicator with an optional status message.
class LoadingView extends StatelessWidget {
  /// Creates a [LoadingView].
  const LoadingView({super.key, this.message = 'Loading...'});

  /// Status message displayed below the progress indicator.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.forest),
          const SizedBox(height: AppSpacing.space16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// An empty state placeholder with an icon, message, and optional action.
class EmptyStateView extends StatelessWidget {
  /// Creates an [EmptyStateView].
  const EmptyStateView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.announce = false,
  });

  /// Headline text for the empty state.
  final String title;

  /// Explanatory message below the title.
  final String message;

  /// Icon displayed above the title.
  final IconData icon;

  /// Label for the optional call to action button.
  final String? actionLabel;

  /// Callback executed when the action button is pressed.
  final VoidCallback? onAction;

  /// Whether to announce the empty-state copy as a semantic live region.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonLabel = actionLabel;
    final buttonAction = onAction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.space16),
            Semantics(
              container: true,
              liveRegion: announce,
              label: announce ? '$title. $message' : null,
              child: ExcludeSemantics(
                excluding: announce,
                child: Column(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (buttonLabel != null && buttonAction != null) ...[
              const SizedBox(height: AppSpacing.space24),
              FilledButton(onPressed: buttonAction, child: Text(buttonLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// An error state placeholder with an optional retry button.
class ErrorView extends StatelessWidget {
  /// Creates an [ErrorView].
  const ErrorView({super.key, required this.message, this.onRetry});

  /// Descriptive error message to display.
  final String message;

  /// Optional callback to retry the failed operation.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.space16),
            Text('Something went wrong', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.space8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.space16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A banner indicating that the device is currently offline.
class OfflineBanner extends StatelessWidget {
  /// Creates an [OfflineBanner].
  const OfflineBanner({
    super.key,
    this.message = 'Working offline. Changes will sync when reconnected.',
  });

  /// The message displayed in the offline banner.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        color: AppColors.statusOffline,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 16, color: AppColors.textOffline),
            const SizedBox(width: AppSpacing.space8),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textOffline),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline error card with a calm heading, message, and retry action.
class InlineErrorCard extends StatelessWidget {
  /// Creates an [InlineErrorCard].
  const InlineErrorCard({
    super.key,
    this.title = "We couldn't load this right now",
    this.message = 'Try again in a moment.',
    this.retryLabel = 'Retry',
    required this.onRetry,
  });

  /// Bold error heading displayed beside the status icon.
  final String title;

  /// Calm explanatory body text beneath [title].
  final String message;

  /// Label for the retry action button.
  final String retryLabel;

  /// Callback invoked when the caregiver taps the retry button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceError,
        border: Border.all(color: AppColors.borderError),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.textError,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

/// An inline offline status card with an optional retry action.
class OfflineStatusCard extends StatelessWidget {
  /// Creates an [OfflineStatusCard].
  const OfflineStatusCard({
    super.key,
    this.title = "You're offline",
    required this.message,
    this.retryLabel = 'Retry',
    this.onRetry,
    this.trailing,
    this.margin,
  });

  /// Bold offline heading displayed beside the offline icon.
  final String title;

  /// Contextual explanation displayed beneath [title].
  final String message;

  /// Label for the optional retry action button.
  final String retryLabel;

  /// Optional callback rendering a retry button when provided.
  final VoidCallback? onRetry;

  /// Optional widget displayed at the end of the header row.
  final Widget? trailing;

  /// Optional outer margin around the card container.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retryCallback = onRetry;
    final trailingWidget = trailing;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOffline,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: AppColors.textOffline,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOffline,
                  ),
                ),
              ),
              ?trailingWidget,
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textOffline,
            ),
          ),
          if (retryCallback != null) ...[
            const SizedBox(height: AppSpacing.space12),
            OutlinedButton(onPressed: retryCallback, child: Text(retryLabel)),
          ],
        ],
      ),
    );
  }
}
