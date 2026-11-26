import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import 'match_detail_screen.dart';

// Plain list of every other startup (scores, tabs and search come in M2)
class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final others = store.startups
            .where((s) => s.id != store.currentId)
            .toList();

        if (others.isEmpty) {
          return const Center(child: Text('No other startups yet.'));
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final s in others) _row(context, s)],
            ),
          ),
        );
      },
    );
  }

  // One startup card. Tap to open its detail page.
  Widget _row(BuildContext context, Startup s) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(store: store, startup: s),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: text.titleMedium),
                    if (s.industry.isNotEmpty)
                      Text(s.industry, style: text.bodyMedium),
                    const SizedBox(height: 12),
                    TagRow(label: 'Offers', tags: s.offers),
                    const SizedBox(height: 8),
                    TagRow(label: 'Needs', tags: s.needs),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// A label followed by tag chips that wrap on narrow screens
class TagRow extends StatelessWidget {
  const TagRow({super.key, required this.label, required this.tags});

  final String label;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        if (tags.isEmpty)
          Text(
            'None yet',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        for (final t in tags)
          Chip(label: Text(t), visualDensity: VisualDensity.compact),
      ],
    );
  }
}
