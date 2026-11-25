import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Gives a popup the standard width (AppSizes); narrow phones use the
/// screen width. Use: `builder: (_) => DialogFrame(child: AlertDialog(...))`.
class DialogFrame extends StatelessWidget {
  const DialogFrame({
    super.key,
    required this.child,
    this.width = AppSizes.confirmDialog,
  });

  final Widget child;

  /// Maximum width (AppSizes.confirmDialog or detailDialog).
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // Plus the dialog's own inset padding on both sides.
        constraints: BoxConstraints(maxWidth: width + 2 * AppSpacing.md),
        child: child,
      ),
    );
  }
}
