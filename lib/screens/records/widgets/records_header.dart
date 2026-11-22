import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// "← Title" row with a thin divider underneath, shared by the Records and
/// Patients screens so they always look the same (as in the prototype).
class RecordsHeader extends StatelessWidget {
  const RecordsHeader({
    super.key,
    required this.onBack,
    this.title = 'Records',
    this.backTooltip = 'Back',
  });

  /// Heading next to the arrow. Defaults to "Records".
  final String title;

  /// Called when the back arrow is tapped.
  final VoidCallback onBack;

  /// Read aloud by screen readers, e.g. "Back to Home".
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                tooltip: backTooltip,
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.navy),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }
}
