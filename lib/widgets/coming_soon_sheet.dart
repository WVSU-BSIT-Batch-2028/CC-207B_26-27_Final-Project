import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import 'h360_button.dart';

/// Friendly stand-in for screens another teammate is still building.
Future<void> showComingSoonSheet(
  BuildContext context, {
  required String title,
  String message = 'This screen is being built by another team member and will plug in here.',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.construction_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.lg),
            H360Button(label: 'Got it', onPressed: () => Navigator.of(sheetContext).pop()),
          ],
        ),
      ),
    ),
  );
}
