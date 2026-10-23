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

/// Shared shadows. Soft, blue-tinted shadows give cards a light, airy feel.
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
