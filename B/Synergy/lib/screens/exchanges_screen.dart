import 'package:flutter/material.dart';

import '../app_store.dart';
import '../widgets/demo_controls.dart';

// Exchanges page: invites to answer, invites sent, and open rooms
class ExchangesScreen extends StatelessWidget {
  const ExchangesScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DemoControls(store: store),
        const SizedBox(height: 24),
        _section(context, 'Needs your reply', _needsReply(context)),
        _section(context, 'Sent', _sent(context)),
        _section(context, 'Rooms', _rooms(context)),
      ],
    );
  }

  // A heading with its content, spaced from the next section
  Widget _section(BuildContext context, String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // Pending invites sent to me, with Accept and Decline
  Widget _needsReply(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.currentId!;
        final waiting = store
            .exchangesFor(me)
            .where((e) => e.recipientId == me && e.stage == 'pending')
            .toList()
            .reversed; // newest first
        if (waiting.isEmpty) {
          return _placeholder(context, 'No introductions are waiting for you.');
        }

        final text = Theme.of(context).textTheme;
        return Column(
          children: [
            for (final e in waiting)
              Card(
                key: ValueKey(e.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.startupById(e.senderId)?.name ??
                            'Unknown startup',
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(e.note, style: text.bodyMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionButton(
                            label: 'Accept',
                            primary: true,
                            onPressed: () => store.acceptInvite(e, me),
                          ),
                          _ActionButton(
                            label: 'Decline',
                            onPressed: () => store.declineInvite(e, me),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Invites I sent, with their status and Withdraw while pending
  Widget _sent(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.currentId!;
        final sent = store
            .exchangesFor(me)
            .where((e) => e.senderId == me)
            .toList()
            .reversed; // newest first
        if (sent.isEmpty) {
          return _placeholder(context, "You haven't sent any introductions.");
        }

        final text = Theme.of(context).textTheme;
        return Column(
          children: [
            for (final e in sent)
              Builder(
                key: ValueKey(e.id),
                builder: (context) {
                  final name =
                      store.startupById(e.recipientId)?.name ??
                      'Unknown startup';
                  final status = switch (e.stage) {
                    'pending' => 'Pending — waiting for $name',
                    'accepted' => 'Accepted',
                    'declined' => 'Declined by $name',
                    'withdrawn' => 'Withdrawn',
                    _ => e.stage,
                  };
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: text.titleSmall),
                          const SizedBox(height: 4),
                          Text(e.note, style: text.bodyMedium),
                          const SizedBox(height: 12),
                          // Status with its action right beside it
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(status, style: text.labelLarge),
                              if (e.stage == 'pending')
                                _ActionButton(
                                  label: 'Withdraw',
                                  onPressed: () => store.withdrawInvite(e, me),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _rooms(BuildContext context) =>
      _placeholder(context, 'Accepted exchanges will show here.');

  Widget _placeholder(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// A button that turns off and shows a spinner while its action saves
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final Future<bool> Function() onPressed; // false = the rule said no
  final bool primary;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await widget.onPressed();
    // On success the card may be gone, so check first
    if (mounted) setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("That action isn't allowed anymore.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(widget.label);
    if (_busy) {
      const spinner = SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      return widget.primary
          ? FilledButton.icon(onPressed: null, icon: spinner, label: label)
          : OutlinedButton.icon(onPressed: null, icon: spinner, label: label);
    }
    return widget.primary
        ? FilledButton(onPressed: _run, child: label)
        : OutlinedButton(onPressed: _run, child: label);
  }
}
