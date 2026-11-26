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

  // Run Campus Grocer's step with the same store action a founder uses
  Future<void> _simulate(Future<bool> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _simulating = true);
    final ok = await action();
    if (mounted) setState(() => _simulating = false);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? done : "That action isn't allowed anymore.")),
    );
  }

  Widget _simulateButton() {
    final store = widget.store;
    final e = _latestWithPartner();
    final action = e == null
        ? null
        : Rules.nextPartnerAction(e, campusGrocerId);

    if (action == 'accept') {
      return _button(
        'Simulate Campus Grocer accepting',
        () => _simulate(
          () => store.acceptInvite(e!, campusGrocerId),
          'Campus Grocer accepted your introduction',
        ),
      );
    }
    if (action == 'agreeTerms') {
      return _button(
        'Simulate Campus Grocer agreeing',
        () => _simulate(
          () => store.agreeTerms(e!, campusGrocerId),
          'Campus Grocer agreed to the terms',
        ),
      );
    }

    if (action == 'confirmStep1') {
      return _button(
        'Simulate Campus Grocer confirming Testers assigned',
        () => _simulate(
          () => store.confirmStep(e!, 1, campusGrocerId),
          'Campus Grocer confirmed Testers assigned',
        ),
      );
    }
    if (action == 'confirmStep2') {
      return _button(
        'Simulate Campus Grocer confirming feedback',
        () => _simulate(
          () => store.confirmStep(e!, 2, campusGrocerId),
          'Campus Grocer confirmed feedback',
        ),
      );
    }

    // Nothing to do: disabled, and the label says why
    final String reason;
    final me = store.currentId;
    if (e == null) {
      reason = 'Send Campus Grocer an introduction first.';
    } else if (e.stage == 'accepted' && !Rules.hasTerms(e)) {
      reason = 'Campus Grocer is waiting for you to propose terms.';
    } else if (Rules.termsLocked(e) && !e.step1ConfirmedBy.contains(me)) {
      reason = 'Campus Grocer is waiting for you to check Testers assigned.';
    } else if (Rules.termsLocked(e) &&
        Rules.stepDone(e, 1) &&
        !e.step2ConfirmedBy.contains(me)) {
      reason = 'Campus Grocer is waiting for your feedback note and check.';
    } else {
      reason = 'Campus Grocer has nothing to do right now.';
    }
    return FilledButton(onPressed: null, child: Text(reason));
  }

  // The simulate button, with a spinner while it saves
  Widget _button(String label, VoidCallback onPressed) {
    return FilledButton.icon(
      onPressed: _simulating ? null : onPressed,
      icon: _simulating
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.smart_toy_outlined),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Demo controls · simulated partner'),
        expandedAlignment: Alignment.centerLeft,
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
