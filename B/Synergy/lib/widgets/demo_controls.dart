import 'package:flutter/material.dart';

import '../app_store.dart';

class DemoControls extends StatelessWidget {
  const DemoControls({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Demo controls · simulated partner'),
        children: [
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await store.reset();
              if (!messenger.mounted) return;
              store.signOut();
              messenger.showSnackBar(
                const SnackBar(content: Text('Demo data reset')),
              );
            },
            child: const Text('Reset demo data'),
          ),
        ],
      ),
    );
  }
}
