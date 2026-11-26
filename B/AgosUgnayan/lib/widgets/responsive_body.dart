// Keeps page content a readable width on big screens (laptop, tablet) while
// it still fills the whole width on a phone. Wrap a screen's body in it.

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// True when the screen is wide enough for the side menu layout.
bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppSizes.wideBreakpoint;

/// Centers [child] at the top and limits it to [maxWidth].
///
/// Use [AppSizes.maxListWidth] (the default) for lists and grids, and
/// [AppSizes.maxFormWidth] for forms and detail pages.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.maxListWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
