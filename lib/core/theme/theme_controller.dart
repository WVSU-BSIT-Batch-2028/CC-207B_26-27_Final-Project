import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Holds the light/dark choice, saves it on the device and tells the app to
/// repaint. Use ThemeController.instance.setMode(ThemeMode.dark) to switch.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const String _storageKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Call once before runApp so the saved choice is applied on launch.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_storageKey) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    AppColors.useDarkPalette(isDark);
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
