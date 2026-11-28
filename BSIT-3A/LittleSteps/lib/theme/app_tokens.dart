import 'package:flutter/material.dart';

/// Color palette tokens for the application.
abstract final class AppColors {
  /// Primary forest green brand color.
  static const forest = Color(0xFF1F634D);

  /// Dark forest accent used for artwork and branding illustrations.
  static const artworkForest = Color(0xFF286B58);

  /// Warm cream background tint.
  static const cream = Color(0xFFF4F2E8);

  /// Soft sage accent color.
  static const sage = Color(0xFF8DAF98);

  /// Warm orange accent color.
  static const orange = Color(0xFFEC6A2C);

  /// Warning and advisory accent color.
  static const warning = orange;

  /// Card and container background surface.
  static const surfaceCard = Color(0xFFFFFFFF);

  /// Scaffold and page canvas background surface.
  static const surfaceCanvas = Color(0xFFF7F7ED);

  /// Light green surface for completed actions and positive indicators.
  static const softGreen = Color(0xFFE0F2E5);

  /// Yellow surface for advisory and informational notices.
  static const surfaceAdvisory = Color(0xFFFAE8A8);

  /// Surface background for offline notices.
  static const surfaceOffline = Color(0xFFF1F5F9);

  /// Light red surface for error banners and validation messages.
  static const surfaceError = Color(0xFFFFF6F5);

  /// Primary high-contrast text color.
  static const textPrimary = Color(0xFF1A2B29);

  /// Secondary text color for captions and metadata.
  static const textSecondary = Color(0xFF5A6A64);

  /// Muted text color for subtle labels and icons.
  static const textTertiary = Color(0xFF7E8C86);

  /// Text color for offline status indicators.
  static const textOffline = Color(0xFF475569);

  /// Text color for error messages and critical notices.
  static const textError = Color(0xFF853029);

  /// Border color for text fields, select inputs, and unselected chips.
  static const borderInput = Color(0xFF7E8C86);

  /// Subtle border color for cards and dividing lines.
  static const borderSubtle = Color(0xFFE0E5DB);

  /// Border color for advisory cards and banners.
  static const borderAdvisory = Color(0xFFD6C88D);

  /// Border color for error states.
  static const borderError = Color(0xFFB83D33);

  /// Focus outline color for interactive controls.
  static const focus = forest;

  /// Critical error color.
  static const error = textError;

  /// Info status background color for metadata and provenance badges.
  static const statusInfo = Color(0xFFD9E8F7);

  /// Info icon foreground color used alongside provenance citations.
  static const infoIcon = Color(0xFF2B6CB0);

  /// Caution status background color.
  static const statusCaution = surfaceAdvisory;

  /// Offline status indicator color.
  static const statusOffline = surfaceOffline;

  /// Primary soft shadow tint for elevated cards.
  static const shadowCard = Color(0x0F1A2B29);

  /// Subtle contact shadow tint for elevated cards.
  static const shadowSubtle = Color(0x0A1A2B29);
}

/// Spacing scale constants based on an 8-point grid.
abstract final class AppSpacing {
  /// 4 dp spacing.
  static const double space4 = 4;

  /// 8 dp spacing.
  static const double space8 = 8;

  /// 12 dp spacing.
  static const double space12 = 12;

  /// 16 dp spacing.
  static const double space16 = 16;

  /// 20 dp spacing.
  static const double space20 = 20;

  /// 24 dp spacing.
  static const double space24 = 24;

  /// 32 dp spacing.
  static const double space32 = 32;
}

/// Corner radius values for controls, containers, and chips.
abstract final class AppRadius {
  /// Radius for shimmer and skeleton placeholders.
  static const double skeleton = 4;

  /// Radius for compact inline badges and small status tags.
  static const double badge = 6;

  /// Radius for buttons, text fields, and inputs.
  static const double control = 10;

  /// Radius for cards and dialogs.
  static const double card = 16;

  /// Radius for pill tags and chips.
  static const double chip = 20;

  /// Top corner radius for modal bottom sheets.
  static const double sheet = 20;
}

/// Typography token constants.
abstract final class AppTypography {
  /// Primary sans-serif font family used across the application.
  static const String fontFamily = 'Inter';
}

/// Layout and interactive dimension constants.
abstract final class AppSizes {
  /// Minimum recommended touch target size for interactive controls.
  static const double touchTarget = 48;

  /// Minimum touch target size for secondary links.
  static const double touchTargetSecondary = 44;

  /// Standard height of the top app bar.
  static const double topBarHeight = 60;

  /// Standard height of the bottom navigation bar.
  static const double bottomBarHeight = 72;

  /// Width of the extended desktop navigation sidebar.
  static const double sidebarWidth = 240;

  /// Maximum readable width for single-column content screens and forms.
  static const double contentMaxWidth = 760;

  /// Maximum width for primary desktop two-column workspace layouts.
  static const double wideContentMaxWidth = 1320;

  /// Maximum width for modal bottom sheets on tablet and desktop viewports.
  static const double sheetMaxWidth = 600;

  /// Maximum width for modal dialogs.
  static const double dialogMaxWidth = 480;

  /// Maximum readable width for centered empty-state and onboarding cards.
  static const double emptyStateMaxWidth = 440;

  /// Viewport width below which the mobile app bar uses a compact icon logo.
  static const double compactHeaderBreakpoint = 380;

  /// Card width at or above which action buttons align inline.
  static const double wideCardBreakpoint = 520;

  /// Minimum viewport width classified as Medium (Material 3 window class).
  static const double mediumLayoutBreakpoint = 600;

  /// Minimum viewport width that switches from bottom bar to side navigation.
  static const double wideLayoutBreakpoint = 840;

  /// Minimum content width that switches single-column tabs to two columns.
  static const double twoColumnBreakpoint = 860;

  /// Minimum viewport width that expands the side navigation rail with labels.
  static const double extendedRailBreakpoint = 1080;

  /// Standard width of the secondary right-hand card column on wide screens.
  static const double sidePanelWidth = 340;

  /// Maximum tile width for responsive multi-column storybook grids.
  static const double bookGridMaxTileExtent = 220;
}

/// Animation durations, feedback timers, and curve constants.
abstract final class AppMotion {
  /// Duration for quick interactive feedback like presses and hover states.
  static const Duration durationFast = Duration(milliseconds: 120);

  /// Duration for modal transitions and expanding views.
  static const Duration durationBase = Duration(milliseconds: 200);

  /// Debounce delay for interactive catalog search inputs.
  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// Brief splash screen delay before initial route resolution.
  static const Duration splashDelay = Duration(milliseconds: 500);

  /// Short snackbar duration for routine confirmations.
  static const Duration snackbarShort = Duration(seconds: 2);

  /// Default snackbar duration for notices and error messages.
  static const Duration snackbarDefault = Duration(seconds: 4);

  /// Extended snackbar duration when an Undo action is offered.
  static const Duration snackbarUndo = Duration(seconds: 10);

  /// Timeout bound for AI recommendation requests.
  static const Duration aiRequestTimeout = Duration(seconds: 8);

  /// Default timeout bound for standard API requests.
  static const Duration apiRequestTimeout = Duration(seconds: 10);

  /// Standard ease-out animation curve.
  static const Curve easingStandard = Cubic(0.2, 0.0, 0.0, 1.0);
}
