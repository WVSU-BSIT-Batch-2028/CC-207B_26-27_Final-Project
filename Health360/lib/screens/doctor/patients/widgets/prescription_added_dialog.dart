
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../widgets/h360_button.dart';

/// The confirmation popup shown after the doctor saves a prescription.
/// It is also used for consultation notes, with a different [message].
class PrescriptionAddedDialog extends StatelessWidget {
  const PrescriptionAddedDialog({
    super.key,
    this.message = 'Prescription added successfully',
  });

  /// The confirmation text displayed next to the check mark.
  final String message;

  @override
  Widget build(BuildContext context) {
    // Colour, corners and outline come from the dialog theme (AppTheme).
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.confirmDialog),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
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
