import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette, type styles and ThemeData for the scrapbook look.
class Paper {
  static const paper = Color(0xFFF4EFE6);
  static const ink = Color(0xFF211C17);
  static const inkSoft = Color(0xFF5B5248);
  static const cobalt = Color(0xFF2B50D9);
  static const tomato = Color(0xFFE4572E);
  static const mustard = Color(0xFFF2C14E);
  static const mint = Color(0xFFA9D8B8);
  static const blush = Color(0xFFF4A6B8);
  static const sky = Color(0xFFBFD0F7);
  static const tape = Color(0xFFEADFC4);
  static const gridLine = Color(0xFF8A9BB5);

  static TextStyle display(double size, {Color color = ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.04,
        letterSpacing: -0.8,
        color: color,
      );

  static TextStyle hand(double size, {Color color = ink}) => GoogleFonts.caveat(
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: color,
  );

  static TextStyle mono(double size, {Color color = ink}) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      );

  static TextStyle body(double size, {Color color = inkSoft}) =>
      GoogleFonts.dmSans(fontSize: size, height: 1.5, color: color);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: cobalt,
      primary: cobalt,
      onPrimary: Colors.white,
      secondary: tomato,
      surface: Colors.white,
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ink, width: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      textTheme: TextTheme(
        headlineMedium: display(34),
        headlineSmall: display(26),
        titleLarge: display(22),
        titleMedium: body(16, color: ink).copyWith(fontWeight: FontWeight.w600),
        titleSmall: body(14, color: ink).copyWith(fontWeight: FontWeight.w600),
        bodyLarge: body(16, color: ink),
        bodyMedium: body(14, color: ink),
        bodySmall: body(12, color: ink),
        labelLarge: body(14, color: ink).copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(22),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ink, width: 1.4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: cobalt, width: 2.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: mono(13, color: Colors.white),
        ),
      ),
    );
  }
}
