import 'package:flutter/material.dart';

/// Spacing scale (use these instead of magic numbers).
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radii.
class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
}

/// Shared soft, blue-tinted card shadows.
class AppShadows {
  AppShadows._();
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x161D4ED8),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

/// Standard popup widths, so every dialog and sheet looks the same.
class AppSizes {
  AppSizes._();

  /// Short confirmations (e.g. "Log out?").
  static const double confirmDialog = 400;

  /// Popups with details (records, lab results, appointments).
  static const double detailDialog = 480;

  /// Bottom sheets.
  static const double sheet = 640;
}
