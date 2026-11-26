// A reusable confirmation for destructive actions such as delete, log out or
// discarding a form. It slides up from the bottom (a bottom sheet), like the
// website. Buttons say what they do ("Delete"), not "Yes" / "No".

import 'package:flutter/material.dart';

import '../utils/strings.dart';
import '../utils/theme.dart';

/// Shows a confirmation sheet and returns true only if the user tapped the
/// confirm button. Tapping Cancel or outside the sheet returns false.
///
/// Example:
/// ```dart
/// final ok = await showConfirmDialog(
///   context,
///   title: 'Delete this crop?',
///   message: 'Tomato, 50 kg will be removed from the marketplace.',
///   confirmLabel: AppStrings.delete,
/// );
/// if (!ok || !context.mounted) return;
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = AppStrings.cancel,
  bool isDestructive = true,
}) async {
  // A sheet that slides up from the bottom, like the website's confirm sheet.
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.lead),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.minTapTarget),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDestructive
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  // The sheet returns null when the user taps outside, so treat it as Cancel.
  return result ?? false;
}

/// Asks "Discard changes?" before leaving a form with unsaved edits.
/// Use it inside a PopScope's onPopInvokedWithResult.
Future<bool> showDiscardChangesDialog(BuildContext context) {
  return showConfirmDialog(
    context,
    title: AppStrings.discardTitle,
    message: AppStrings.discardMessage,
    confirmLabel: AppStrings.discard,
    cancelLabel: AppStrings.keepEditing,
  );
}
