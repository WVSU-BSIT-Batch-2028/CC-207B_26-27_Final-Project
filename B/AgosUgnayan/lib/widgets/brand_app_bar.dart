// The green top bar of the main tabs: logo and "AgosUgnayan" on the left,
// icon buttons on the right. Inner pages use a normal AppBar with a back
// arrow and a title instead.

import 'package:flutter/material.dart';

import '../utils/strings.dart';
import '../utils/theme.dart';

/// The AgosUgnayan logo image (the same file as the website's logo).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        // Decorative: the app name is always written next to it.
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Top bar with the logo, for the main screen.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.actions});

  /// Icon buttons on the right, e.g. Profile.
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Row(
        children: [
          AppLogo(),
          SizedBox(width: AppSizes.small),
          Text(AppStrings.appName, style: AppTextStyles.logo),
        ],
      ),
      actions: [...?actions, const SizedBox(width: 4)],
    );
  }
}
