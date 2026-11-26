import 'package:flutter/material.dart';

import '../app_store.dart';

// Exchanges page: invites to answer, invites sent, and open rooms
class ExchangesScreen extends StatelessWidget {
  const ExchangesScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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

  // Placeholders until M1 steps 3 and 4
  Widget _needsReply(BuildContext context) =>
      _placeholder(context, 'Invites sent to you will show here.');

  Widget _sent(BuildContext context) =>
      _placeholder(context, 'Invites you sent will show here.');

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
