import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A banner displaying a non-diagnostic advisory notice.
class AdvisoryBanner extends StatelessWidget {
  /// Creates an [AdvisoryBanner].
  const AdvisoryBanner({
    super.key,
    this.title,
    this.message = 'Not a diagnostic tool. Observational play suggestions only. You know your child best.',
    this.onDismiss,
    this.dismissTooltip,
    this.margin,
  });

  /// Optional bold heading displayed above [message].
  final String? title;

  /// The text message displayed in the banner.
  final String message;

  /// Optional callback rendering a close button when provided.
  final VoidCallback? onDismiss;

  /// Optional semantic tooltip for the dismiss button.
  final String? dismissTooltip;

  /// Optional outer margin around the banner container.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAdvisory,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderAdvisory),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading != null) ...[
                  Text(
                    heading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              padding: EdgeInsets.zero,
              tooltip: dismissTooltip,
              constraints: dismissTooltip != null
                  ? const BoxConstraints(
                      minWidth: AppSizes.touchTarget,
                      minHeight: AppSizes.touchTarget,
                    )
                  : const BoxConstraints(),
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
