import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// How large text is across the app (helps older users).
enum TextSize { normal, large, extraLarge }

extension TextSizeX on TextSize {
  String get label {
    switch (this) {
      case TextSize.normal:
        return 'Normal';
      case TextSize.large:
        return 'Large';
      case TextSize.extraLarge:
        return 'Extra large';
    }
  }

  /// Multiplier applied on top of the device's own text-size setting.
  double get factor {
    switch (this) {
      case TextSize.normal:
        return 1.0;
      case TextSize.large:
        return 1.15;
      case TextSize.extraLarge:
        return 1.3;
    }
  }
}

/// Holds the appearance choices (light/dark and text size), saves them on the
/// device and tells the app to repaint.
/// Use ThemeController.instance.setMode(ThemeMode.dark) or setTextSize(TextSize.large).
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const String _storageKey = 'theme_mode';
  static const String _textSizeKey = 'text_size';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  TextSize _textSize = TextSize.normal;
  TextSize get textSize => _textSize;

  /// Call once before runApp so the saved choice is applied on launch.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_storageKey) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final savedSize = prefs.getString(_textSizeKey);
    _textSize = TextSize.values.firstWhere((s) => s.name == savedSize, orElse: () => TextSize.normal);
    AppColors.useDarkPalette(isDark);
  }

  /// Text size only needs MediaQuery to change, so no forced rebuild is needed.
  Future<void> setTextSize(TextSize size) async {
    if (size == _textSize) return;
    _textSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textSizeKey, size.name);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    AppColors.useDarkPalette(isDark); // switch the palette first...
    notifyListeners(); // ...then rebuild MaterialApp (ThemeData)...
    _rebuildEverything(); // ...and every widget that reads AppColors.

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, isDark ? 'dark' : 'light');
  }

  /// AppColors are plain getters, so widgets are not notified when they change.
  /// Marking every element dirty makes the whole tree rebuild with the new
  /// colours without losing the current screen or its state.
  void _rebuildEverything() {
    void markDirty(Element element) {
      element.markNeedsBuild();
      element.visitChildren(markDirty);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(markDirty);
  }
}
