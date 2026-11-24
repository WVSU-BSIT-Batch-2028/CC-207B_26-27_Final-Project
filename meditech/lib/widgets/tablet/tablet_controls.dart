import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Toolbar and action control sizes shared by pharmacy and admin tablet screens
class TabletControls {
  static const actionHeight = 48.0;
  static const toolbarHeight = 42.0;

  static ButtonStyle toolbarOutlined({
    Color border = AppColors.border,
    Color foreground = AppColors.text,
    Color? background,
  }) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(0, toolbarHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: border),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  static ButtonStyle actionFilled({Color? background}) => FilledButton.styleFrom(
        minimumSize: const Size(64, actionHeight),
        backgroundColor: background,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      );

  static ButtonStyle actionOutlined({
    Color foreground = AppColors.primary,
    Color border = AppColors.primary,
    Color? background,
  }) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(64, actionHeight),
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: border),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      );

  static ButtonStyle dangerOutlined() => OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(actionHeight),
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      );

  static InputDecoration searchDecoration({required String hint, Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );
}