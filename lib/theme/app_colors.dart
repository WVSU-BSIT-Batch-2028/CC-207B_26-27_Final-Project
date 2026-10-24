import 'package:flutter/material.dart';

/// All colors used by WEBSUPARK, kept in one place.
/// NOTE: these values are estimates taken from the prototype screenshots.
/// They must be checked against the prototype with a color picker.
class AppColors {
  // Private constructor: this class only holds constants,
  // so nobody should create an AppColors object.
  AppColors._();

  // Brand colors
  static const Color primary = Color(0xFF1B4F8F); // title pill, headings
  static const Color primaryLight = Color(0xFF38A8D8); // end of the pill gradient
  static const Color navy = Color(0xFF14325A); // dark cards in the driver app
  static const Color sidebar = Color(0xFF060E1E); // head security sidebar
  static const Color action = Color(0xFF1F5FEB); // bright blue buttons

  // Status colors (soft = pale background for chips and badges)
  static const Color success = Color(0xFF24865B);
  static const Color successSoft = Color(0xFFE3F4EA);
  static const Color warning = Color(0xFFE5A100);
  static const Color warningSoft = Color(0xFFFFF1CC);
  static const Color danger = Color(0xFFD62839);
  static const Color dangerSoft = Color(0xFFFDE4E6);

  // Neutral colors
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF14233A);
  static const Color textMuted = Color(0xFF64748B);
}