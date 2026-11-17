import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item.dart';

// Loads and changes the signed-in branch's inventory
abstract class InventoryService {
  Future<List<InventoryItem>> loadInventory();
  Future<List<CatalogueMedicine>> loadCatalogue();
  Future<void> addItem({
    required String medicineId,
    required int stockQuantity,
    required double price,
    int lowStockThreshold = 10,
    DateTime? nearestExpiry,
  });
  Future<void> updateItem({
    required String itemId,
    int? stockQuantity,
    double? price,
    int? lowStockThreshold,
    DateTime? nearestExpiry,
    bool clearExpiry = false,
  });
  Future<void> setOutOfStock(List<String> itemIds);
  Future<void> backInStock(Map<String, int> shelfCounts);
  Future<void> setListingActive(List<String> itemIds, bool active);
}

class SupabaseInventoryService implements InventoryService {
  SupabaseClient get _client => Supabase.instance.client;

  // Turns a date into the YYYY-MM-DD text the database expects
  String? _day(DateTime? d) => d?.toIso8601String().substring(0, 10);

  @override
  Future<List<InventoryItem>> loadInventory() async {
    final rows = await _client.from('inventory_items').select(
        '*, medicines(brand_name, generic_name, strength, is_rx, '
        'dosage_forms(name), units(name))');
    return [for (final row in rows) InventoryItem.fromJson(row)];
  }

  @override
  Future<List<CatalogueMedicine>> loadCatalogue() async {
    final rows = await _client
        .from('medicines')
        .select('id, brand_name, generic_name, strength, is_rx, '
            'dosage_forms(name), units(name)')
        .eq('status', 'active')
        .order('brand_name');
    return [for (final row in rows) CatalogueMedicine.fromJson(row)];
  }

  @override
  Future<void> addItem({
    required String medicineId,
    required int stockQuantity,
    required double price,
    int lowStockThreshold = 10,
    DateTime? nearestExpiry,
  }) async {
    await _client.rpc('add_inventory_item', params: {
      'p_medicine_id': medicineId,
      'p_stock_quantity': stockQuantity,
      'p_price_per_unit': price,
      'p_low_stock_threshold': lowStockThreshold,
      'p_nearest_expiry': _day(nearestExpiry),
    });
  }

  @override
  Future<void> updateItem({
    required String itemId,
    int? stockQuantity,
    double? price,
    int? lowStockThreshold,
    DateTime? nearestExpiry,
    bool clearExpiry = false,
  }) async {
    await _client.rpc('update_inventory_item', params: {
      'p_item_id': itemId,
      'p_stock_quantity': stockQuantity,
      'p_price_per_unit': price,
      'p_low_stock_threshold': lowStockThreshold,
      'p_nearest_expiry': _day(nearestExpiry),
      'p_clear_expiry': clearExpiry,
    });
  }

  @override
  Future<void> setOutOfStock(List<String> itemIds) async {
    await _client.rpc('set_out_of_stock', params: {'p_item_ids': itemIds});
  }

  @override
  Future<void> backInStock(Map<String, int> shelfCounts) async {
    await _client.rpc('back_in_stock', params: {
      'p_items': [
        for (final e in shelfCounts.entries)
          {'item_id': e.key, 'quantity': e.value},
      ],
    });
  }

  @override
  Future<void> setListingActive(List<String> itemIds, bool active) async {
    await _client.rpc('set_listing_active',
        params: {'p_item_ids': itemIds, 'p_active': active});
  }
}