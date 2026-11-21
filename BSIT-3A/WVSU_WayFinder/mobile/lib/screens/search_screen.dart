import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final q = query.trim();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Search', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      // keyed so the box always shows exactly what the student typed
      SearchField(key: ValueKey(query), initial: query, autofocus: q.isEmpty),
      if (q.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 12), child: Text('Type a room code like CB 203, or an office or building name.', style: TextStyle(color: muted)))
      else
        Loader<List<PlaceView>>(
          loadKey: q,
          what: 'search results',
          load: () => scope.places.search(q),
          builder: (context, results) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (scope.places.isDemo) const Notice('Supabase is not configured. Showing DEMO records, not official WVSU information.'),
            if (results.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('No match for “$query”', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'We don’t have ${scope.places.isDemo ? 'a demo record' : 'a verified place'} with that code or name. Check the spelling, or try another search above.',
                      style: const TextStyle(color: muted),
                    ),
                  ]),
                ),
              ),
            for (final v in results) PlaceCard(view: v),
          ]),
        ),
    ]);
  }
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.view});
  final PlaceView view;

  @override
  Widget build(BuildContext context) {
    final p = view.place;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(p.kind.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
            StatusBadge(p.status),
          ]),
          const SizedBox(height: 6),
          Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          PlaceFacts(view),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton(onPressed: () => context.go('/place/${p.id}'), child: const Text('View details')),
            OutlinedButton.icon(
              onPressed: () => context.go('/map?place=${p.id}'),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('Show on Map'),
            ),
          ]),
        ]),
      ),
    );
  }
}
