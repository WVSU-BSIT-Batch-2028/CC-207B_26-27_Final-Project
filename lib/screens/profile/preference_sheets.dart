import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';

const ShapeBorder _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
);

/// Language picker. Only English is available for now.
void showLanguageSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: _sheetShape,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Language', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            ListTile(
              title: const Text('English'),
              trailing: Icon(Icons.check_circle_rounded, color: AppColors.primary),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('More languages are planned.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Light / Dark picker. The choice is applied immediately and saved.
void showThemeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: _sheetShape,
    builder: (sheetContext) {
      Widget option(String label, IconData icon, ThemeMode mode) {
        final selected = ThemeController.instance.mode == mode;
        return ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: selected ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
          onTap: () {
            ThemeController.instance.setMode(mode);
            Navigator.of(sheetContext).pop();
          },
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('App Theme', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
              option('Light', Icons.light_mode_rounded, ThemeMode.light),
              option('Dark', Icons.dark_mode_rounded, ThemeMode.dark),
            ],
          ),
        ),
      );
    },
  );
}
