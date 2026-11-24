import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/h360_button.dart';

/// The shared look of the Records popups (Medical Record, Lab Results):
/// a rounded card with a title, scrollable content and a Close button.
class RecordPopup extends StatelessWidget {
  const RecordPopup({super.key, required this.title, required this.child});

  /// Heading at the top, e.g. "Medical Record".
  final String title;

  /// The content between the title and the Close button.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Colour, corners and outline come from the dialog theme (AppTheme).
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSizes.detailDialog,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: AppSpacing.md),

              // Content scrolls if it is taller than the screen (small phones, large text)
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: AppSpacing.md),

              // Close button, bottom right (as in the prototype)
              Align(
                alignment: Alignment.centerRight,
                child: H360Button(
                  label: 'Close',
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

/// Centered bold heading of one section inside a popup.
class PopupSectionTitle extends StatelessWidget {
  const PopupSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
    );
  }
}

/// One "Label: value" line. Text.rich lets a long value wrap naturally.
class PopupInfoLine extends StatelessWidget {
  const PopupInfoLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
    );
  }
}

/// Paragraph text inside a popup (15 is above the minimum of 14).
class PopupBodyText extends StatelessWidget {
  const PopupBodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.textPrimary),
    );
  }
}

/// Thin line between sections of a popup.
class PopupSectionDivider extends StatelessWidget {
  const PopupSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Divider(height: 1, thickness: 1, color: AppColors.border),
    );
  }
}
