// App colors, sizes, text styles and the Material theme.
// Every value matches the AgosUgnayan website (app/src/styles/tokens.css in
// the agosugnayan repo), so the Flutter app looks like the website. Screens
// never hard-code a color or size. To change the look of the whole app, edit here.

import 'package:flutter/material.dart';

/// Colors from the website's design tokens. The comment after each one says
/// where it is used, and the CSS variable name in brackets.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1F5FA8); // top bar, buttons (--brand)
  static const Color primaryDark = Color(0xFF1E5631); // prices (--gdark)
  static const Color link = Color(0xFF3E7D3A); // links, outlines (--g600)
  static const Color primaryLight = Color(
    0xFFE3EFE5,
  ); // tiles, nav pill (--g50)
  static const Color onPrimaryMuted = Color(0xFFDDEBD3); // subtitle on green
  static const Color background = Color(0xFFF5F5F0); // page (--bg)
  static const Color surface = Colors.white; // cards, inputs (--surface)
  static const Color border = Color(0xFFE6E6DF); // cards (--border)
  static const Color line = Color(0xFFCFCFC4); // chips, inputs (--line)
  static const Color text = Color(0xFF1F1F1A); // (--text)
  static const Color textMuted = Color(0xFF64645A); // meta text (--muted)
  static const Color segmented = Color(0xFFEEEEE7); // grey boxes (--grey-50)
  static const Color accent = Color(0xFFD9822B); // badges, counts (--orange)
  static const Color accentInk = Color(0xFF2E1C0B); // text on orange
  static const Color warningLight = Color(
    0xFFFDF0DC,
  ); // warning box (--amber-50)
  static const Color warningInk = Color(0xFF8A5300); // warning icon
  static const Color danger = Color(0xFFC62828); // errors, price drop (--down)
  static const Color dangerLight = Color(0xFFFBEAEA); // error box (--red-50)
  static const Color dangerStrong = Color(0xFFB3261E); // error toast
  static const Color info = Color(0xFF1F5FA8); // "Answered" status (--blue)
  static const Color infoLight = Color(0xFFE4EDF8);
  static const Color toast = Color(0xFF1F2A1A); // snackbar background
  static const Color toastAction = Color(0xFF9BD48A); // snackbar button
}

/// Spacing and corner radius values (8 px grid, like the website).
class AppSizes {
  AppSizes._();

  static const double pagePadding = 16; // side margins on phones
  static const double sectionGap = 20; // between sections
  static const double fieldGap = 16; // between form fields
  static const double labelGap = 6;
  static const double small = 8;

  static const double radiusCard = 12; // (--radius-card)
  static const double radiusButton = 10; // (--radius-btn)
  static const double radiusInput = 10;
  static const double radiusChip = 18;
  static const double radiusSmallButton = 8;
  static const double radiusSheet = 18;

  static const double minTapTarget = 48; // accessibility minimum

  /// Screens at least this wide get the side menu instead of bottom tabs.
  static const double wideBreakpoint = 600;

  /// Screens at least this wide get the full sidebar with labels.
  static const double desktopBreakpoint = 1000;

  /// Side margins on tablets and laptops (more room, so a bit more space).
  static const double pagePaddingWide = 24;

  /// Widest a list or grid page gets on a big screen, so lines stay readable.
  static const double maxListWidth = 1200;

  /// Widest a form or detail page gets on a big screen.
  static const double maxFormWidth = 720;
}

/// Font family names. The font files are in assets/fonts and listed in
/// pubspec.yaml under `fonts:`; the names here must match the `family:` there.
class AppFonts {
  AppFonts._();

  static const String body = 'Inter';
  static const String display = 'BarlowCondensed';
}

/// Text styles that Material's TextTheme doesn't cover.
class AppTextStyles {
  AppTextStyles._();

  /// Big uppercase page title, e.g. "MY CROPS" (website .ptitle).
  static const TextStyle pageTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 28,
    height: 1.0,
    color: AppColors.text,
  );

  /// Small green uppercase line above a page title (website .eyebrow).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 1.1,
    color: AppColors.link,
  );

  /// Grey sentence under a page title (website .lead).
  static const TextStyle lead = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    color: AppColors.textMuted,
  );

  /// Section heading inside a page, e.g. "Your listings".
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.text,
  );

  /// The "AgosUgnayan" word next to the logo in the top bar.
  static const TextStyle logo = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 23,
    color: Colors.white,
  );

  /// A price in dark green, e.g. "₱45.00" (website .price).
  static const TextStyle price = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: AppColors.primaryDark,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Small grey text: places, dates, sources (website .meta).
  static const TextStyle meta = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    color: AppColors.textMuted,
  );

  /// The big number on a stat tile, e.g. "12" crops listed.
  static const TextStyle statNumber = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 30,
    height: 1.0,
    color: AppColors.text,
  );

  /// The name on a card or list row, e.g. "Tomato".
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.text,
  );

  /// "See all" style link next to a section heading.
  static const TextStyle link = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors.link,
  );
}

/// Builds the app-wide [ThemeData] so buttons, inputs, cards and navigation
/// look like the website without styling each widget by hand.
ThemeData buildAppTheme() {
  const inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusInput)),
    borderSide: BorderSide(color: AppColors.line),
  );
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusButton)),
  );
  const buttonText = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.link,
      error: AppColors.danger,
      surface: AppColors.surface,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 15, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    // Green top bar, 56 px tall, 17 px title (website .top).
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      titleSpacing: 4,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: Colors.white,
      ),
    ),
    // Flat white cards with a thin border (website .card).
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusCard)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    // 48 px inputs; errors get a red outline on a light red fill (website .inp).
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      floatingLabelStyle: const TextStyle(
        color: AppColors.link,
        fontWeight: FontWeight.w600,
      ),
      errorStyle: const TextStyle(
        color: AppColors.danger,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.link, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    ),
    // Primary button: green, white text, 48 px tall (website .btn-primary).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(64, AppSizes.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: buttonText,
        shape: buttonShape,
      ),
    ),
    // Outline button: green border and text on white (website .btn-outline).
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.link,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: const BorderSide(color: AppColors.link, width: 1.5),
        textStyle: buttonText.copyWith(fontSize: 14),
        shape: buttonShape,
      ),
    ),
    // Text button: green text, no box (website .btn-text).
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.link,
        minimumSize: const Size(44, 44),
        textStyle: buttonText.copyWith(fontSize: 14),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedTextStyle: buttonText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusCard)),
      ),
    ),
    // Chips: white with a grey outline; selected ones turn brand green with
    // white text (website .chip and .chip.on).
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.line,
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusChip)),
      ),
    ),
    // Segmented control: grey track, white selected part (website .seg).
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.segmented,
        selectedBackgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMuted,
        selectedForegroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.segmented, width: 3),
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSizes.radiusButton),
          ),
        ),
      ),
    ),
    // Bottom tabs: white bar, light green pill behind the current tab.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryLight,
      surfaceTintColor: Colors.transparent,
      height: 66,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : AppColors.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : AppColors.textMuted,
        ),
      ),
    ),
    // Side menu on wide screens: same colors as the bottom tabs.
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryLight,
      selectedIconTheme: IconThemeData(color: AppColors.primaryDark),
      unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
      selectedLabelTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    ),
    // Toasts: dark green-black box with a light green action (website .toast).
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.toast,
      actionTextColor: AppColors.toastAction,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      width: 456,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusCard)),
      ),
    ),
    // Bottom sheets: rounded top corners (website .sheet).
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      constraints: BoxConstraints(maxWidth: 560),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusSheet),
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusSheet)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
  );
}
