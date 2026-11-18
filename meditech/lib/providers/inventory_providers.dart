import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_item.dart';
import '../services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return SupabaseInventoryService();
});

// The branch's inventory list; call ref.invalidate after any change
final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryServiceProvider).loadInventory();
});

// Medicines a pharmacy may pick from when adding inventory
final catalogueProvider = FutureProvider<List<CatalogueMedicine>>((ref) {
  return ref.watch(inventoryServiceProvider).loadCatalogue();
});