import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Material 3 window width classes used to drive adaptive layout decisions.
///
/// Layout switches strictly on available window width rather than physical
/// device type so foldables, split-screen mobile, tablets, and resizable
/// desktop/web windows all adapt smoothly.
enum AppWindowSize {
  /// Narrow phone portrait layouts (`< 600 dp`).
  compact,

  /// Medium layouts such as large phones in landscape, foldables, or portrait
  /// tablets (`600 – 839 dp`).
  medium,

  /// Wide layouts such as landscape tablets and desktop windows (`>= 840 dp`).
  expanded;

  /// Classifies a layout [width] in logical pixels into an [AppWindowSize].
  static AppWindowSize fromWidth(double width) {
    if (width >= AppSizes.wideLayoutBreakpoint) return AppWindowSize.expanded;
    if (width >= AppSizes.mediumLayoutBreakpoint) return AppWindowSize.medium;
    return AppWindowSize.compact;
  }

  /// Resolves the current [AppWindowSize] from [MediaQuery.sizeOf].
  static AppWindowSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}

/// Constrains [child] to a readable maximum width and aligns it horizontally.
///
/// Prevents single-column forms, lists, and detail pages from stretching
/// unnaturally across wide tablet or desktop screens.
class ResponsiveContentBox extends StatelessWidget {
  /// Creates a [ResponsiveContentBox].
  const ResponsiveContentBox({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.contentMaxWidth,
    this.alignment = Alignment.center,
  });

  /// Content constrained to [maxWidth].
  final Widget child;

  /// Maximum allowed horizontal width in logical pixels.
  final double maxWidth;

  /// Alignment applied around the constrained child.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Arranges a [primary] pane and optional [secondary] pane stacked on narrow
/// viewports and side-by-side at or above [breakpoint].
class AdaptiveTwoPane extends StatelessWidget {
  /// Creates an [AdaptiveTwoPane].
  const AdaptiveTwoPane({
    super.key,
    required this.primary,
    this.secondary,
    this.breakpoint = AppSizes.twoColumnBreakpoint,
    this.sideWidth = AppSizes.sidePanelWidth,
    this.horizontalSpacing = AppSpacing.space24,
    this.verticalSpacing = AppSpacing.space20,
  });

  /// Primary content column expanded on wide viewports.
  final Widget primary;

  /// Optional secondary side panel stacked below [primary] on compact widths.
  final Widget? secondary;

  /// Minimum available width at which panes display side by side.
  final double breakpoint;

  /// Fixed width allocated to [secondary] in two-column mode.
  final double sideWidth;

  /// Horizontal gap between [primary] and [secondary] in two-column mode.
  final double horizontalSpacing;

  /// Vertical gap between [primary] and [secondary] in stacked mode.
  final double verticalSpacing;

  @override
  Widget build(BuildContext context) {
    final sidePane = secondary;
    if (sidePane == null) return primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: primary),
              SizedBox(width: horizontalSpacing),
              SizedBox(width: sideWidth, child: sidePane),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            SizedBox(height: verticalSpacing),
            sidePane,
          ],
        );
      },
    );
  }
}
