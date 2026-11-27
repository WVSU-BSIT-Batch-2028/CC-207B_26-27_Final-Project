import 'package:flutter/material.dart';

/// Shared palette. Change brand colors here rather than in individual screens.
class FoodWiseColors {
  FoodWiseColors._();
  static const background = Color(0xFFFFF8F1);
  static const surface = Color(0xFFFFFFFF);
  static const orange = Color(0xFFFF8A24);
  static const deepOrange = Color(0xFFE96B10);
  static const lightOrange = Color(0xFFFFE7D1);
  static const paleOrange = Color(0xFFFFF1E5);
  static const charcoal = Color(0xFF30251F);
  static const muted = Color(0xFF88786E);
  static const border = Color(0xFFF0DFD2);
  static const hint = Color(0xFF88786E);
  static const passwordIcon = orange;
  static const success = Color(0xFF166534);
  static const error = Color(0xFFB91C1C);
  static const warning = Color(0xFF92400E);
  static const info = Color(0xFF1D4ED8);
  static const errorBorder = Color(0xFFE8A5A5);
  static const shadow = Color(0xFF000000);
  static const overlay = Color(0x42000000);
  static const transparent = Color(0x00000000);

  // Compatibility aliases for existing groupmate code.
  static const sage = orange;
  static const deepSage = deepOrange;
  static const lightSage = lightOrange;
  static const beige = lightOrange;
}

class FoodWiseSpacing {
  FoodWiseSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
}

class FoodWiseRadius {
  FoodWiseRadius._();
  static const double indicator = 3;
  static const double small = 8;
  static const double compact = 12;
  static const double feedback = 14;
  static const double brand = 15;
  static const double control = 16;
  static const double medium = 17;
  static const double tile = 18;
  static const double large = 20;
  static const double panel = 22;
  static const double largePanel = 23;
  static const double dialog = 24;
  static const double pill = 30;
}

class FoodWiseTypeSize {
  FoodWiseTypeSize._();
  static const double micro = 10;
  static const double overline = 11;
  static const double caption = 12;
  static const double supporting = 13;
  static const double body = 14;
  static const double button = 15;
  static const double bodyLarge = 16;
  static const double cardTitle = 17;
  static const double subtitle = 18;
  static const double sectionSmall = 19;
  static const double section = 20;
  static const double sectionLarge = 21;
  static const double profileTitle = 22;
  static const double brand = 23;
  static const double hero = 26;
  static const double pageTitle = 27;
  static const double pageLarge = 28;
  static const double displaySmall = 30;
  static const double display = 32;
}

class FoodWiseTypography {
  FoodWiseTypography._();
  static const pageTitle = TextStyle(
    fontSize: FoodWiseTypeSize.pageTitle,
    fontWeight: FontWeight.w900,
    color: FoodWiseColors.charcoal,
  );
  static const sectionTitle = TextStyle(
    fontSize: FoodWiseTypeSize.section,
    fontWeight: FontWeight.w800,
    color: FoodWiseColors.charcoal,
  );
  static const body = TextStyle(
    fontSize: FoodWiseTypeSize.body,
    color: FoodWiseColors.charcoal,
    height: 1.5,
  );
  static const caption = TextStyle(
    fontSize: FoodWiseTypeSize.caption,
    color: FoodWiseColors.muted,
  );
  static const button = TextStyle(
    fontSize: FoodWiseTypeSize.button,
    fontWeight: FontWeight.w700,
  );
}

class FoodWiseTheme {
  FoodWiseTheme._();

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(FoodWiseRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );

  static RoundedRectangleBorder _shape(double radius, {Color? border}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border == null ? BorderSide.none : BorderSide(color: border),
      );

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: FoodWiseColors.deepOrange,
          brightness: Brightness.light,
        ).copyWith(
          primary: FoodWiseColors.deepOrange,
          onPrimary: FoodWiseColors.surface,
          secondary: FoodWiseColors.orange,
          secondaryContainer: FoodWiseColors.lightOrange,
          onSecondaryContainer: FoodWiseColors.charcoal,
          surface: FoodWiseColors.surface,
          onSurface: FoodWiseColors.charcoal,
          onSurfaceVariant: FoodWiseColors.muted,
          outline: FoodWiseColors.border,
          error: FoodWiseColors.error,
          onError: FoodWiseColors.surface,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      scaffoldBackgroundColor: FoodWiseColors.background,
      textTheme: base.textTheme.copyWith(
        headlineMedium: FoodWiseTypography.pageTitle,
        titleLarge: FoodWiseTypography.sectionTitle,
        bodyMedium: FoodWiseTypography.body,
        bodySmall: FoodWiseTypography.caption,
        labelLarge: FoodWiseTypography.button,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FoodWiseColors.background,
        foregroundColor: FoodWiseColors.charcoal,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: FoodWiseColors.transparent,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: FoodWiseColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: FoodWiseColors.muted),
        hintStyle: const TextStyle(color: FoodWiseColors.hint),
        prefixIconColor: FoodWiseColors.deepOrange,
        suffixIconColor: FoodWiseColors.passwordIcon,
        border: _inputBorder(FoodWiseColors.border),
        enabledBorder: _inputBorder(FoodWiseColors.border),
        focusedBorder: _inputBorder(FoodWiseColors.orange, width: 1.6),
        errorBorder: _inputBorder(FoodWiseColors.error),
        focusedErrorBorder: _inputBorder(FoodWiseColors.error, width: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FoodWiseColors.deepOrange,
          foregroundColor: FoodWiseColors.surface,
          minimumSize: const Size(0, 54),
          elevation: 0,
          shape: _shape(FoodWiseRadius.control),
          textStyle: FoodWiseTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FoodWiseColors.deepOrange,
          side: const BorderSide(color: FoodWiseColors.border),
          minimumSize: const Size(0, 48),
          shape: _shape(FoodWiseRadius.control),
          textStyle: FoodWiseTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FoodWiseColors.deepOrange,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: FoodWiseColors.surface,
        elevation: 0,
        surfaceTintColor: FoodWiseColors.transparent,
        shape: _shape(FoodWiseRadius.tile, border: FoodWiseColors.border),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FoodWiseColors.surface,
        surfaceTintColor: FoodWiseColors.transparent,
        shape: _shape(FoodWiseRadius.dialog),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: FoodWiseColors.paleOrange,
        selectedColor: FoodWiseColors.lightOrange,
        checkmarkColor: FoodWiseColors.deepOrange,
        side: const BorderSide(color: FoodWiseColors.border),
        shape: _shape(FoodWiseRadius.compact),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FoodWiseColors.deepOrange,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FoodWiseColors.charcoal,
        contentTextStyle: const TextStyle(color: FoodWiseColors.surface),
        shape: _shape(FoodWiseRadius.feedback),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: FoodWiseColors.surface,
        indicatorColor: FoodWiseColors.lightOrange,
      ),
    );
  }
}
