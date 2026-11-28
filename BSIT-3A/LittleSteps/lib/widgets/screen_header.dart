import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Consistent top header for primary screen views.
///
/// Renders the page title, an optional contextual subtitle, and an optional
/// non-diagnostic advisory link.
class ScreenHeader extends StatelessWidget {
  /// Creates a [ScreenHeader].
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onAdvisoryTap,
    this.advisoryLabel = 'Not a diagnostic tool',
  });

  /// Main page title.
  final String title;

  /// Optional subtitle displayed beneath [title].
  final String? subtitle;

  /// Optional callback invoked when the advisory link is tapped.
  final VoidCallback? onAdvisoryTap;

  /// Visible and semantic label for the advisory link.
  final String advisoryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleText = subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitleText != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            subtitleText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (onAdvisoryTap != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Semantics(
            button: true,
            label: advisoryLabel,
            child: InkWell(
              onTap: onAdvisoryTap,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.touchTargetSecondary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 15,
                      color: AppColors.forest,
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    Text(
                      advisoryLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.forest,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
