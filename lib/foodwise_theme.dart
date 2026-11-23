import 'package:flutter/material.dart';

class FoodWiseColors {
  static const background = Color(0xFFF5F1E8);
  static const surface = Color(0xFFFFFEFA);

  static const sage = Color(0xFF718873);
  static const deepSage = Color(0xFF526B57);
  static const lightSage = Color(0xFFE8EDE5);

  static const beige = Color(0xFFE9DFC9);

  static const charcoal = Color(0xFF26332B);
  static const muted = Color(0xFF788078);
  static const border = Color(0xFFE6E1D7);
}

class FoodWiseTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: FoodWiseColors.background,

      colorScheme:
          ColorScheme.fromSeed(
            seedColor: FoodWiseColors.deepSage,
            brightness: Brightness.light,
          ).copyWith(
            primary: FoodWiseColors.deepSage,
            secondary: FoodWiseColors.sage,
            surface: FoodWiseColors.surface,
            onSurface: FoodWiseColors.charcoal,
          ),

      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: FoodWiseColors.background,
        foregroundColor: FoodWiseColors.charcoal,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FoodWiseColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 19,
        ),
        labelStyle: const TextStyle(color: FoodWiseColors.muted),
        prefixIconColor: FoodWiseColors.sage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: FoodWiseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: FoodWiseColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: FoodWiseColors.sage, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FoodWiseColors.deepSage,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
