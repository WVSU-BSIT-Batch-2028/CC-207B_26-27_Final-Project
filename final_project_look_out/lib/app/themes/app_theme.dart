import 'package:flutter/material.dart';
import './app_colors.dart';

// Created AppTheme with lightTheme and darkTheme configurations - Lianne
class AppTheme {
  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColor.bgColor,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColor.primaryBlue,
        brightness: Brightness.light,
        surface: AppColor.surfaceLight,
        error: AppColor.errorRed,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColor.surfaceLight,
        indicatorColor: AppColor.primaryBlue.withValues(alpha: 0.15),
      ),

      dividerTheme: DividerThemeData(
        color: AppColor.textSecondaryLight.withValues(alpha: 0.2),
        thickness: 1,
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColor.textPrimaryLight,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColor.textPrimaryLight,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColor.textSecondaryLight,
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColor.bgColorDark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColor.primaryBlue,
        brightness: Brightness.dark,
        surface: AppColor.surfaceDark,
        error: AppColor.errorRed,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.surfaceDark,
        foregroundColor: AppColor.textPrimaryDark,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColor.surfaceDark,
        indicatorColor: AppColor.primaryBlue.withValues(alpha: 0.25),
      ),

      dividerTheme: DividerThemeData(
        color: AppColor.textSecondaryDark.withValues(alpha: 0.2),
        thickness: 1,
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColor.textPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColor.textPrimaryDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColor.textSecondaryDark,
        ),
      ),
    );
  }
}
