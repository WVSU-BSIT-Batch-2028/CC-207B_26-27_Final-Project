// One shared widget for the four states of any screen that loads data:
// loading, error (with Try again), empty (with an optional action) and data.
// Using it everywhere keeps every screen consistent.

import 'package:flutter/material.dart';

import '../utils/strings.dart';
import '../utils/theme.dart';

/// Shows a spinner, an error with a Try again button, an empty message, or
/// the real content, in that order of priority.
///
/// Example:
/// ```dart
/// AsyncStateView(
///   isLoading: _loading,
///   errorMessage: _error,
///   onRetry: _load,
///   isEmpty: _items.isEmpty,
///   emptyMessage: 'No crops yet. Tap + to add one.',
///   builder: (context) => ListView(...),
/// )
/// ```
class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.emptyMessage,
    required this.builder,
    this.errorMessage,
    this.onRetry,
    this.emptyAction,
  });

  /// True while the data is still loading.
  final bool isLoading;

  /// A friendly error message, or null when there is no error.
  final String? errorMessage;

  /// Called when the user taps "Try again".
  final VoidCallback? onRetry;

  /// True when loading finished but there is nothing to show.
  final bool isEmpty;

  /// What to say when the list is empty, e.g. "No requests yet."
  final String emptyMessage;

  /// Optional button under the empty message, e.g. "Add crop".
  final Widget? emptyAction;

  /// Builds the real content once data is ready.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // Spinner plus "Loading…", like the website's loading line.
      return const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                semanticsLabel: AppStrings.loading,
              ),
            ),
            SizedBox(width: 10),
            Text(AppStrings.loading, style: AppTextStyles.lead),
          ],
        ),
      );
    }
    if (errorMessage != null) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        isProblem: true,
        message: errorMessage!,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
      );
    }
    if (isEmpty) {
      return _Message(
        icon: Icons.inbox_outlined,
        message: emptyMessage,
        action: emptyAction,
      );
    }
    return builder(context);
  }
}

/// Centered icon in a circle, message and optional button, used for error
/// and empty. Errors get a red circle so they don't look like "no data".
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.action,
    this.isProblem = false,
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final bool isProblem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isProblem
                    ? AppColors.dangerLight
                    : AppColors.primaryLight,
              ),
              child: Icon(
                icon,
                size: 26,
                color: isProblem ? AppColors.danger : AppColors.link,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSizes.fieldGap),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
