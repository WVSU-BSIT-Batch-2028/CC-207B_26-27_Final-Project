import 'package:flutter/material.dart';

class FoodWiseColors {
  static const background = Color(0xFFFFF8F1);
  static const surface = Color(0xFFFFFFFF);
  static const orange = Color(0xFFFF8A24);
  static const deepOrange = Color(0xFFE96B10);
  static const lightOrange = Color(0xFFFFE7D1);
  static const paleOrange = Color(0xFFFFF1E5);
  static const charcoal = Color(0xFF30251F);
  static const muted = Color(0xFF88786E);
  static const border = Color(0xFFF0DFD2);

  // Compatibility aliases used by the existing registration and home screens.
  static const sage = orange;
  static const deepSage = deepOrange;
  static const lightSage = lightOrange;
  static const beige = lightOrange;
}

class FoodWiseTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: FoodWiseColors.deepOrange,
      brightness: Brightness.light,
    ).copyWith(
      primary: FoodWiseColors.deepOrange,
      secondary: FoodWiseColors.orange,
      surface: FoodWiseColors.surface,
      onSurface: FoodWiseColors.charcoal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: FoodWiseColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: FoodWiseColors.background,
        foregroundColor: FoodWiseColors.charcoal,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FoodWiseColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
        labelStyle: const TextStyle(color: FoodWiseColors.muted),
        hintStyle: const TextStyle(color: Color(0xFFB6A79D)),
        prefixIconColor: FoodWiseColors.deepOrange,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FoodWiseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FoodWiseColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FoodWiseColors.orange, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FoodWiseColors.deepOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FoodWiseColors.deepOrange,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
