import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../widgets/h360_button.dart';

/// The "Prescription added successfully" confirmation popup, shown after the
/// doctor saves a prescription. The doctor must tap OK to continue.
class PrescriptionAddedDialog extends StatelessWidget {
  const PrescriptionAddedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Small heading
              Text(
                'Confirmation',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),

              // Message + check mark (an icon as well as text, not colour alone)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prescription added successfully',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 32),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // OK button
              Center(
                child: H360Button(
                  label: 'OK',
                  expanded: false,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
