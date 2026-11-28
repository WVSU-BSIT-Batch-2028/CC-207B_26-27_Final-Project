import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Semantic status colors used throughout the theme.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  /// Creates a set of semantic status color pairs.
  const AppStatusColors({
    required this.cautionBackground,
    required this.cautionForeground,
    required this.softGreenBackground,
    required this.softGreenForeground,
    required this.infoBackground,
    required this.infoForeground,
    required this.offlineBackground,
    required this.offlineForeground,
    required this.errorBackground,
    required this.errorForeground,
  });

  /// Background color for caution and advisory indicators.
  final Color cautionBackground;

  /// Foreground color for text and icons on [cautionBackground].
  final Color cautionForeground;

  /// Background color for completed actions and positive states.
  final Color softGreenBackground;

  /// Foreground color for text and icons on [softGreenBackground].
  final Color softGreenForeground;

  /// Background color for informational tags and source labels.
  final Color infoBackground;

  /// Foreground color for text and icons on [infoBackground].
  final Color infoForeground;

  /// Background color for offline notices.
  final Color offlineBackground;

  /// Foreground color for text and icons on [offlineBackground].
  final Color offlineForeground;

  /// Background color for error containers.
  final Color errorBackground;

  /// Foreground color for text and icons on [errorBackground].
  final Color errorForeground;

  /// Default light theme status colors.
  static const light = AppStatusColors(
    cautionBackground: AppColors.statusCaution,
    cautionForeground: AppColors.textPrimary,
    softGreenBackground: AppColors.softGreen,
    softGreenForeground: AppColors.forest,
    infoBackground: AppColors.statusInfo,
    infoForeground: AppColors.textPrimary,
    offlineBackground: AppColors.statusOffline,
    offlineForeground: AppColors.textOffline,
    errorBackground: AppColors.surfaceError,
    errorForeground: AppColors.textError,
  );

  @override
  AppStatusColors copyWith({
    Color? cautionBackground,
    Color? cautionForeground,
    Color? softGreenBackground,
    Color? softGreenForeground,
    Color? infoBackground,
    Color? infoForeground,
    Color? offlineBackground,
    Color? offlineForeground,
    Color? errorBackground,
    Color? errorForeground,
  }) {
    return AppStatusColors(
      cautionBackground: cautionBackground ?? this.cautionBackground,
      cautionForeground: cautionForeground ?? this.cautionForeground,
      softGreenBackground: softGreenBackground ?? this.softGreenBackground,
      softGreenForeground: softGreenForeground ?? this.softGreenForeground,
      infoBackground: infoBackground ?? this.infoBackground,
      infoForeground: infoForeground ?? this.infoForeground,
      offlineBackground: offlineBackground ?? this.offlineBackground,
      offlineForeground: offlineForeground ?? this.offlineForeground,
      errorBackground: errorBackground ?? this.errorBackground,
      errorForeground: errorForeground ?? this.errorForeground,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      cautionBackground: Color.lerp(
        cautionBackground,
        other.cautionBackground,
        t,
      )!,
      cautionForeground: Color.lerp(
        cautionForeground,
        other.cautionForeground,
        t,
      )!,
      softGreenBackground: Color.lerp(
        softGreenBackground,
        other.softGreenBackground,
        t,
      )!,
      softGreenForeground: Color.lerp(
        softGreenForeground,
        other.softGreenForeground,
        t,
      )!,
      infoBackground: Color.lerp(infoBackground, other.infoBackground, t)!,
      infoForeground: Color.lerp(infoForeground, other.infoForeground, t)!,
      offlineBackground: Color.lerp(
        offlineBackground,
        other.offlineBackground,
        t,
      )!,
      offlineForeground: Color.lerp(
        offlineForeground,
        other.offlineForeground,
        t,
      )!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorForeground: Color.lerp(errorForeground, other.errorForeground, t)!,
    );
  }
}

/// Application theme definitions.
abstract final class AppTheme {
  /// Builds the light theme data.
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      onPrimary: AppColors.surfaceCard,
      error: AppColors.error,
      onError: AppColors.surfaceCard,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderInput,
      outlineVariant: AppColors.borderSubtle,
    );

    final controlRadius = BorderRadius.circular(AppRadius.control);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.surfaceCanvas,
      extensions: const [AppStatusColors.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceCanvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: AppSizes.topBarHeight,
        iconTheme: IconThemeData(color: AppColors.forest),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.bottomBarHeight,
        backgroundColor: AppColors.surfaceCard,
        indicatorColor: AppColors.softGreen,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.forest);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 32 / 26,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space24),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space24),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          side: const BorderSide(color: AppColors.borderInput),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        enabledBorder: inputBorder(AppColors.borderInput),
        focusedBorder: inputBorder(AppColors.forest, 2),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 2),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    );
  }
}
