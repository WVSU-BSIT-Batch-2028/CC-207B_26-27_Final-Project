import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Gives a popup the standard width (AppSizes), so every dialog in the app
/// has the same proportion on a phone and in a wide browser window.
///
/// Wrap an AlertDialog (or Dialog) in it inside `showDialog`'s builder:
///   builder: (_) => DialogFrame(child: AlertDialog(...))
/// On a narrow phone the dialog simply uses the screen width.
class DialogFrame extends StatelessWidget {
  const DialogFrame({
    super.key,
    required this.child,
    this.width = AppSizes.confirmDialog,
  });

  final Widget child;

  /// The dialog's maximum width (use AppSizes.confirmDialog or detailDialog).
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // The dialog adds its inset padding (AppSpacing.md) on both sides.
        constraints: BoxConstraints(maxWidth: width + 2 * AppSpacing.md),
        child: child,
      ),
    );
  }
}
