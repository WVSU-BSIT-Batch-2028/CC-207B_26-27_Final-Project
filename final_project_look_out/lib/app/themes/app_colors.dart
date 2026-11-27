import 'package:flutter/material.dart';

// Added color palette for light and dark modes - Lianne
class AppColor {
  // Brand / Primary Colors
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color secondaryTeal = Color(0xFF26A69A);
  static const Color brandNavy = Color(0xFF101C35);

  // Light Mode Colors
  static const Color bgColor = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1C1E);
  static const Color textSecondaryLight = Color(0xFF6C757D);

  // Dark Mode Colors
  static const Color bgColorDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFE2E2E6);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // Status / Alert Colors
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color warningYellow = Color(0xFFFFA000);

  // Additional UI Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color dividerLight = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF333333);
  static const Color disabled = Color(0xFF9E9E9E);

  // Navigation / Interaction Colors
  static const Color selectedLight = Color(0xFF1E88E5);
  static const Color selectedDark = Color(0xFF90CAF9);
  static const Color unselectedLight = Color(0xFF6C757D);
  static const Color unselectedDark = Color(0xFFB0B0B0);
}
