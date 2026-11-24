import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import 'session_providers.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return SupabaseInventoryService();
});

// The branch's inventory list with realtime subscription to inventory_items table
final inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, List<InventoryItem>>(
  InventoryNotifier.new,
);

class InventoryNotifier extends AsyncNotifier<List<InventoryItem>> {
  RealtimeChannel? _channel;

  @override
  Future<List<InventoryItem>> build() async {
    ref.onDispose(_unsubscribe);

    restoreSessionIfNeeded(
      currentSession: ref.read(sessionProvider),
      setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
    );
    ref.listen(sessionProvider, (prev, next) {
      if (prev?.branchId != next?.branchId || (prev == null) != (next == null)) {
        ref.invalidateSelf();
      }
    });

    final branchId = ref.watch(sessionProvider)?.branchId;
    if (branchId != null) {
      _subscribeToInventoryChanges(branchId);
    }

    return ref.watch(inventoryServiceProvider).loadInventory();
  }

  void _subscribeToInventoryChanges(String branchId) {
    _unsubscribe();
    try {
      final client = Supabase.instance.client;
      _channel = client
          .channel('branch-inventory-$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inventory_items',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (_) {
              ref.invalidateSelf();
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime optional when offline or in preview/test mode
    }
  }

  void _unsubscribe() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {}
    }
  }
}

// Medicines a pharmacy may pick from when adding inventory
final catalogueProvider = FutureProvider<List<CatalogueMedicine>>((ref) {
  return ref.watch(inventoryServiceProvider).loadCatalogue();
});