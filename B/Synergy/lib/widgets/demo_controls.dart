import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../rules.dart';

// Simulated partner button and Reset, for one-tab demos
class DemoControls extends StatefulWidget {
  const DemoControls({super.key, required this.store});

  final AppStore store;

  @override
  State<DemoControls> createState() => _DemoControlsState();
}

class _DemoControlsState extends State<DemoControls> {
  bool _simulating = false; // true while the simulated step saves

  // The signed-in founder's newest exchange with Campus Grocer
  Exchange? _latestWithPartner() {
    final me = widget.store.currentId;
    if (me == null || me == campusGrocerId) return null;
    return widget.store
        .exchangesFor(me)
        .where(
          (e) =>
              e.senderId == campusGrocerId || e.recipientId == campusGrocerId,
        )
        .lastOrNull;
  }

  Future<void> _simulateAccept(Exchange e) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _simulating = true);
    // Same action a real founder uses, with Campus Grocer as the actor
    final ok = await widget.store.acceptInvite(e, campusGrocerId);
    if (mounted) setState(() => _simulating = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Campus Grocer accepted your introduction'
              : "That action isn't allowed anymore.",
        ),
      ),
    );
  }

  Widget _simulateButton() {
    final e = _latestWithPartner();
    final action = e == null
        ? null
        : Rules.nextPartnerAction(e, campusGrocerId);

    if (action == 'accept') {
      return FilledButton.icon(
        onPressed: _simulating ? null : () => _simulateAccept(e!),
        icon: _simulating
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.smart_toy_outlined),
        label: const Text('Simulate Campus Grocer accepting'),
      );
    }

    // Nothing to do: disabled, and the label says why
    final open = e != null && !['declined', 'withdrawn'].contains(e.stage);
    return FilledButton(
      onPressed: null,
      child: Text(
        open
            ? 'Campus Grocer has nothing to do right now.'
            : 'Campus Grocer has nothing to do yet. '
                  'Send them an introduction first.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Demo controls · simulated partner'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // Redraw the button when exchanges change
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => _simulateButton(),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await widget.store.reset();
              if (!messenger.mounted) return;
              widget.store.signOut();
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
