import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../widgets/h360_button.dart';

const ShapeBorder _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
);

/// App Theme sheet: Light / Dark and Text size. Changes apply immediately and
/// are saved; the sheet stays open so you can see the effect, then tap Done.
void showThemeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: _sheetShape,
    constraints: const BoxConstraints(maxWidth: AppSizes.sheet),
    builder: (sheetContext) => ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;

        Widget heading(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            );

        Widget themeOption(String label, IconData icon, ThemeMode mode) => ListTile(
              leading: Icon(icon, color: AppColors.primary),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: controller.mode == mode
                  ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () => controller.setMode(mode),
            );

        Widget sizeOption(TextSize size) => ListTile(
              // "Aa" previews roughly how big that size is.
              leading: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 18 * size.factor,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              title: Text(size.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: controller.textSize == size
                  ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () => controller.setTextSize(size),
            );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                heading('Theme'),
                themeOption('Light', Icons.light_mode_rounded, ThemeMode.light),
                themeOption('Dark', Icons.dark_mode_rounded, ThemeMode.dark),
                heading('Text size'),
                sizeOption(TextSize.normal),
                sizeOption(TextSize.large),
                sizeOption(TextSize.extraLarge),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: H360Button(label: 'Done', onPressed: () => Navigator.of(sheetContext).pop()),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
