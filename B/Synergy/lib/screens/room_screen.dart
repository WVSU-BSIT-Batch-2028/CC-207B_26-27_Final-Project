import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../widgets/demo_controls.dart';
import '../widgets/milestone_panel.dart';
import '../widgets/terms_panel.dart';

// Readable name for an exchange stage
String stageLabel(String stage) => switch (stage) {
  'pending' => 'Pending',
  'accepted' => 'Accepted',
  'termsAgreed' => 'Terms agreed',
  'declined' => 'Declined',
  'withdrawn' => 'Withdrawn',
  _ => stage,
};

// The shared room for one accepted exchange
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.store, required this.exchangeId});

  final AppStore store;
  final String exchangeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Room')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          // Look it up each time so changes show right away
          final e = store.exchanges
              .where((x) => x.id == exchangeId)
              .firstOrNull;
          if (e == null) {
            return const Center(child: Text('This room no longer exists.'));
          }

          // Signed-in startup on the left, partner on the right
          final me = store.currentId;
          final partnerId = e.senderId == me ? e.recipientId : e.senderId;
          final theme = Theme.of(context);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: _startupCard(context, me ?? '')),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.handshake_outlined),
                      ),
                      Expanded(child: _startupCard(context, partnerId)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stageLabel(e.stage),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 24),

                  TermsPanel(store: store, exchange: e),
                  MilestonePanel(key: ValueKey(e.id), store: store, exchange: e),

                  // Filled in by later milestones
                  _placeholder(
                    context,
                    'Review (M5)',
                    'Rate each other once the exchange is launched.',
                  ),
                  const SizedBox(height: 12),
                  DemoControls(store: store),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // One startup's name and industry in the header
  Widget _startupCard(BuildContext context, String id) {
    final Startup? s = store.startupById(id);
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              s?.name ?? 'Unknown startup',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            if (s != null && s.industry.isNotEmpty)
              Text(
                s.industry,
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, String title, String hint) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
