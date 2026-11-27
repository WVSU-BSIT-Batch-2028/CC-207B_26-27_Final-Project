import 'package:flutter/material.dart';

class LookOutDrawer extends StatelessWidget {
  final Widget header;
  final List<Widget> items;

  const LookOutDrawer({
    super.key,
    required this.items,
    required this.header,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            header,
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }
}
