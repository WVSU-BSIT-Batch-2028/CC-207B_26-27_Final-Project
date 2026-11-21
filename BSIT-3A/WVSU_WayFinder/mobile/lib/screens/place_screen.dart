import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class PlaceScreen extends StatelessWidget {
  const PlaceScreen({super.key, required this.placeId});
  final String placeId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Home')),
      Loader<PlaceView?>(
        loadKey: placeId,
        what: 'this place',
        load: () => scope.places.getPlace(placeId),
        builder: (context, v) {
          if (v == null) {
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No place has the ID “$placeId”.')));
          }
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(v.place.kind.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
                  StatusBadge(v.place.status),
                ]),
                const SizedBox(height: 6),
                Text(v.place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                PlaceFacts(v),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => context.go('/map?place=${v.place.id}'),
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: const Text('Show on Map'),
                ),
                const SizedBox(height: 8),
                Text('Place ID: ${v.place.id}', style: const TextStyle(fontSize: 12, color: muted)),
              ]),
            ),
          );
        },
      ),
    ]);
  }
}
