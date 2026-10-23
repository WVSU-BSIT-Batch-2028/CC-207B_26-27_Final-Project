import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Temporary screen for tabs owned by other teammates. Replace the
/// placeholder in the shell with your real screen when it is ready.
/// Centered both ways, with a max width so it also looks right on wide screens.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.title, required this.icon, required this.hint});

  final String title;
  final IconData icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
