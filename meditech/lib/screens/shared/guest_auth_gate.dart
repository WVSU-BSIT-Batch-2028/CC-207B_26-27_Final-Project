import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/theme/app_colors.dart';
import '../../widgets/theme/app_spacing.dart';
import 'sign_in_sheet.dart';

// Guest barrier that matches the Main Flow prompt before credentials
Future<bool> showGuestAuthGate(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.lock_outline, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, 'sign-in'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text('Sign in'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext, 'sign-up'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text('Create an account'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, 'dismiss'),
              child: const Text('Not now'),
            ),
          ],
        ),
      );
    },
  );

  if (!context.mounted) return false;

  if (action == 'sign-up') {
    context.push('/sign-up');
    return false;
  }

  if (action != 'sign-in') return false;

  await showCustomerSignInSheet(context);
  return false;
}
