import 'package:flutter/material.dart';

import '../models/child.dart';
import '../theme/app_tokens.dart';

/// A header chip displaying the active child profile.
class ChildChip extends StatelessWidget {
  /// Creates a [ChildChip].
  const ChildChip({
    super.key,
    required this.activeChild,
    this.onTap,
    this.compact = false,
  });

  /// The active child profile, or `null` if none is selected.
  final Child? activeChild;

  /// Callback invoked when the chip is tapped.
  final VoidCallback? onTap;

  /// Whether to render only the nickname while keeping the full semantics label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = activeChild;
    final label = child != null
        ? '${child.nickname} (${child.ageBand})'
        : 'Select child';
    final visibleLabel = compact && child != null ? child.nickname : label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.touchTargetSecondary,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space8,
          ),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  visibleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: compact && activeChild != null ? label : null,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space4),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppColors.forest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
