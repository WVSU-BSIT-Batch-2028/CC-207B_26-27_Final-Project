import 'package:flutter/material.dart';
import 'package:websupark/theme/app_colors.dart';

/// Keeps a phone-designed screen at phone width and centered
/// when it is shown in a wide browser window.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}