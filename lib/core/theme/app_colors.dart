import 'package:flutter/material.dart';

/// The neutral colours that change between light and dark mode.
class AppPalette {
  const AppPalette({
    required this.mist,
    required this.surface,
    required this.border,
    required this.skeleton,
    required this.textPrimary,
    required this.textMuted,
    required this.navy,
    required this.primary,
  });

  final Color mist; // page background
  final Color surface; // cards, sheets
  final Color border;
  final Color skeleton; // loading placeholders
  final Color textPrimary;
  final Color textMuted;
  final Color navy; // headings
  final Color primary; // action blue

  static const AppPalette light = AppPalette(
    mist: Color(0xFFEEF3FD),
    surface: Colors.white,
    border: Color(0xFFD4E0F7),
    skeleton: Color(0xFFDCE6FA),
    textPrimary: Color(0xFF0F1F4D),
    textMuted: Color(0xFF4A5A80),
    navy: Color(0xFF12296B),
    primary: Color(0xFF1D4ED8),
  );

  static const AppPalette night = AppPalette(
    mist: Color(0xFF0B1426),
    surface: Color(0xFF14203A),
    border: Color(0xFF263759),
    skeleton: Color(0xFF1D2B4A),
    textPrimary: Color(0xFFE9EFFF),
    textMuted: Color(0xFFB0BEDC),
    navy: Color(0xFFD7E3FF),
    primary: Color(0xFF4A7BF7),
  );
}

/// App colour palette. Neutral colours are getters that follow light/dark
/// mode, so they cannot be used in `const` widgets.
class AppColors {
  AppColors._();

  static AppPalette _palette = AppPalette.light;

  /// Called by ThemeController when the mode changes.
  static void useDarkPalette(bool dark) {
    _palette = dark ? AppPalette.night : AppPalette.light;
  }

  static bool get isDark => identical(_palette, AppPalette.night);

  // Theme-aware
  static Color get mist => _palette.mist;
  static Color get surface => _palette.surface;
  static Color get border => _palette.border;
  static Color get skeleton => _palette.skeleton;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textMuted => _palette.textMuted;
  static Color get navy => _palette.navy;
  static Color get primary => _palette.primary;

  // Fixed (same in light and dark)
  /// Always-dark navy, for fills behind white icons or text.
  static const Color brandNavy = Color(0xFF12296B);
  static const Color primaryLight = Color(0xFF60A5FA);

  // Status
  static const Color success = Color(0xFF0E9F6E);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFE11D48);

  // Vitals
  static const Color heart = Color(0xFFE11D48);
  static const Color pressure = Color(0xFF0EA5E9);
  static const Color weight = Color(0xFF059669);
  static const Color sleep = Color(0xFF6D5BD0);

  /// Gradient for hero cards and the AI badge.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12296B), Color(0xFF1D4ED8), Color(0xFF3B82F6)],
  );
}
