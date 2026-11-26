// The layout of every main tab (My Crops, Prices, Market, ...): the page
// heading at the top, the content below it, and both kept to a readable
// width on big screens. The green top bar and the tabs come from HomeScreen.

import 'package:flutter/material.dart';

import '../utils/theme.dart';
import 'responsive_body.dart';

/// [header] stays at the top; [child] (usually a list) fills the rest.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.header,
    required this.child,
    this.maxWidth = AppSizes.maxListWidth,
  });

  /// Usually a PageHeader, maybe with search or filter chips under it.
  final Widget header;

  /// The page content. Lists should use [TabPage.listPadding].
  final Widget child;

  final double maxWidth;

  /// Padding for a list under the header: page margins, and room at the
  /// bottom so the last card is not hidden.
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(
    AppSizes.pagePadding,
    4,
    AppSizes.pagePadding,
    32,
  );

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.pagePadding,
              AppSizes.pagePadding,
              14,
            ),
            child: header,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
