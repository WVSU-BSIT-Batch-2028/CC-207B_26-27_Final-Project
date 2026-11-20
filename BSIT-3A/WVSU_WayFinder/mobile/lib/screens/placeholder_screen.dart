import 'package:flutter/material.dart';

import '../core/theme.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('This screen is planned for a later phase and is not built yet.', style: TextStyle(color: muted)))),
      ]);
}
