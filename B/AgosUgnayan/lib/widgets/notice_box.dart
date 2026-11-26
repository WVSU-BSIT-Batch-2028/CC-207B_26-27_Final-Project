// A colored box with an icon and a short message, like the website's
// notices: green for tips, blue for info, amber for warnings, red for errors.
// One color per meaning, and always with text.

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// What the notice is about. It decides the colors and the icon.
enum NoticeKind { tip, info, warning, error }

/// e.g. an amber "Prices are from your last visit" box.
class NoticeBox extends StatelessWidget {
  const NoticeBox({
    super.key,
    required this.message,
    this.kind = NoticeKind.tip,
  });

  final String message;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final (background, edge, iconColor, icon) = switch (kind) {
      NoticeKind.tip => (
        AppColors.primaryLight,
        null,
        AppColors.link,
        Icons.lightbulb_outline,
      ),
      NoticeKind.info => (
        AppColors.infoLight,
        AppColors.info,
        AppColors.info,
        Icons.info_outline,
      ),
      NoticeKind.warning => (
        AppColors.warningLight,
        AppColors.accent,
        AppColors.warningInk,
        Icons.warning_amber_rounded,
      ),
      NoticeKind.error => (
        AppColors.dangerLight,
        AppColors.danger,
        AppColors.danger,
        Icons.error_outline,
      ),
    };
    // ClipRRect rounds the corners. (Flutter can't round a box whose border
    // is only on one side, so the stripe and the corners are done separately.)
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusButton),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: background,
          // A colored stripe on the left for info, warnings and errors.
          border: edge == null
              ? null
              : Border(left: BorderSide(color: edge, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.text,
                  fontWeight: kind == NoticeKind.error
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
