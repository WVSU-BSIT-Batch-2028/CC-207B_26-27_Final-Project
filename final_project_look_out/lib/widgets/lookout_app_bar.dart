import 'package:flutter/material.dart';

class LookOutAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onMenuPressed;

  const LookOutAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: onMenuPressed != null
      ? IconButton(
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
        onPressed: onMenuPressed,
        icon: const Icon(Icons.menu), 
      )
      :leading,

      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}