import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../rules.dart';
import 'match_detail_screen.dart';

// Suggested, Saved and Browse all, with search by name
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Name contains the search text, ignoring case
  List<Startup> _filter(List<Startup> list) {
    final q = _search.text.trim().toLowerCase();
    return list.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  static int _byName(Startup a, Startup b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search startups by name',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Suggested'),
                  Tab(text: 'Saved'),
                  Tab(text: 'Browse all'),
                ],
              ),
              Expanded(
                // Redraws when profiles or saved startups change
                child: ListenableBuilder(
                  listenable: widget.store,
                  builder: (context, _) => _tabs(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearSearch() => setState(() => _search.clear());

  Widget _tabs() {
    final me = widget.store.currentStartup!;
    final others = widget.store.startups.where((s) => s.id != me.id).toList()
      ..sort(_byName);

    // Fit above 0, highest first, ties by name
    final suggested = others.where((s) => Rules.matchFit(me, s) > 0).toList()
      ..sort((a, b) {
        final byFit = Rules.matchFit(me, b).compareTo(Rules.matchFit(me, a));
        return byFit != 0 ? byFit : _byName(a, b);
      });
    final saved = others.where((s) => me.savedIds.contains(s.id)).toList();

    return TabBarView(
      children: [
        _list(
          me,
          suggested,
          emptyText:
              'No suggested matches yet. Add offer and need tags '
              'on My startup.',
        ),
        _list(
          me,
          saved,
          emptyText: 'Nothing saved yet',
          emptyAction: Builder(
            // Switch to the Browse all tab
            builder: (context) => FilledButton(
              onPressed: () => DefaultTabController.of(context).animateTo(2),
              child: const Text('Browse matches'),
            ),
          ),
        ),
        _list(me, others, emptyText: 'No other startups yet.'),
      ],
    );
  }

  // One tab: the cards, or a message when empty
  Widget _list(
    Startup me,
    List<Startup> all, {
    required String emptyText,
    Widget? emptyAction,
  }) {
    if (all.isEmpty) return _message(emptyText, emptyAction);
    final shown = _filter(all);
    if (shown.isEmpty) {
      return _message(
        'No startups match',
        OutlinedButton(
          onPressed: _clearSearch,
          child: const Text('Clear search'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final s in shown) _card(me, s)],
    );
  }

  Widget _message(String text, Widget? action) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    ),
  );

  // One match card. Tap to open Why this match.
  Widget _card(Startup me, Startup s) {
    final theme = Theme.of(context);
    final isSaved = me.savedIds.contains(s.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(store: widget.store, startup: s),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: theme.textTheme.titleMedium),
                    if (s.industry.isNotEmpty)
                      Text(s.industry, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${Rules.matchFit(me, s)}% tag fit',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'They offer ${tagList(Rules.theyOffer(me, s))} · '
                      'You offer ${tagList(Rules.youOffer(me, s))}',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isSaved ? 'Saved' : 'Save',
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                color: theme.colorScheme.primary,
                onPressed: () => widget.store.toggleSaved(s.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tags as "A, B", or "nothing" if empty
String tagList(List<String> tags) => tags.isEmpty ? 'nothing' : tags.join(', ');

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
