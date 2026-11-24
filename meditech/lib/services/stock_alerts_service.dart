import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item.dart';
import '../models/stock_alert_item.dart';

// Service for fetching live stock alerts calculated directly from inventory items
class StockAlertsService {
  StockAlertsService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    final client = _providedClient;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  // Pure function computing alert categories directly from inventory items
  static Map<StockAlertType, List<StockAlertItem>> computeAlertsFromInventory(
      List<InventoryItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final sixtyDaysFromNow = today.add(const Duration(days: 60));

    final lowStock = <StockAlertItem>[];
    final outOfStock = <StockAlertItem>[];
    final expiringSoon = <StockAlertItem>[];
    final notUpdated = <StockAlertItem>[];

    for (final item in items) {
      if (!item.isActive) continue;

      final stock = item.stockQuantity;
      final held = item.heldQuantity;
      final threshold = item.lowStockThreshold;
      final isOutOfStock = item.outOfStock;
      final expiry = item.nearestExpiry;
      final confirmedAt = item.stockConfirmedAt;
      final available = item.availableQuantity;

      StockAlertItem createAlertItem(StockAlertType type) => StockAlertItem(
            id: item.id,
            inventoryItemId: item.id,
            medicineId: item.medicineId,
            brandName: item.brandName,
            genericName: item.genericName,
            strength: item.strength,
            dosageForm: item.dosageForm,
            unit: item.unit,
            stockQuantity: stock,
            heldQuantity: held,
            lowStockThreshold: threshold,
            nearestExpiry: expiry,
            stockConfirmedAt: confirmedAt,
            outOfStock: isOutOfStock,
            alertType: type,
          );

      if (available >= 1 && available <= threshold && !isOutOfStock) {
        lowStock.add(createAlertItem(StockAlertType.lowStock));
      }

      if (available <= 0 || isOutOfStock) {
        outOfStock.add(createAlertItem(StockAlertType.outOfStock));
      }

      if (expiry != null &&
          !expiry.isBefore(today) &&
          expiry.isBefore(sixtyDaysFromNow)) {
        expiringSoon.add(createAlertItem(StockAlertType.expiringSoon));
      }

      if (confirmedAt.isBefore(sevenDaysAgo)) {
        notUpdated.add(createAlertItem(StockAlertType.notUpdated));
      }
    }

    return {
      StockAlertType.lowStock: lowStock,
      StockAlertType.outOfStock: outOfStock,
      StockAlertType.expiringSoon: expiringSoon,
      StockAlertType.notUpdated: notUpdated,
    };
  }

  // Returns all alert items categorized into the 4 tabs
  Future<Map<StockAlertType, List<StockAlertItem>>> loadStockAlerts() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final sixtyDaysFromNow = today.add(const Duration(days: 60));

    final response = await _client.from('inventory_items').select(
          'id, medicine_id, stock_quantity, held_quantity, '
          'low_stock_threshold, nearest_expiry, stock_confirmed_at, '
          'out_of_stock_flag, is_active, '
          'medicines(brand_name, generic_name, strength, '
          'dosage_forms(name), units(name))',
        );

    final lowStock = <StockAlertItem>[];
    final outOfStock = <StockAlertItem>[];
    final expiringSoon = <StockAlertItem>[];
    final notUpdated = <StockAlertItem>[];

    for (final row in response as List) {
      final map = row as Map<String, dynamic>;
      final med = map['medicines'] as Map<String, dynamic>? ?? {};
      final dosageFormMap = med['dosage_forms'] as Map<String, dynamic>?;
      final unitMap = med['units'] as Map<String, dynamic>?;

      final stock = (map['stock_quantity'] as num?)?.toInt() ?? 0;
      final held = (map['held_quantity'] as num?)?.toInt() ?? 0;
      final threshold = (map['low_stock_threshold'] as num?)?.toInt() ?? 10;
      final isOutOfStock = map['out_of_stock_flag'] == true;
      final isActive = map['is_active'] == true;
      if (!isActive) continue;

      final expiry = map['nearest_expiry'] != null
          ? DateTime.tryParse(map['nearest_expiry'].toString())
          : null;
      final confirmedAt = map['stock_confirmed_at'] != null
          ? DateTime.tryParse(map['stock_confirmed_at'].toString())
          : null;

      final available = stock - held;

      final itemData = {
        'id': map['id'],
        'inventory_item_id': map['id'],
        'medicine_id': map['medicine_id'],
        'brand_name': med['brand_name'] ?? '',
        'generic_name': med['generic_name'] ?? '',
        'strength': med['strength'] ?? '',
        'dosage_form': dosageFormMap?['name'] ?? '',
        'unit': unitMap?['name'] ?? 'unit',
        'stock_quantity': stock,
        'held_quantity': held,
        'low_stock_threshold': threshold,
        'nearest_expiry': expiry?.toIso8601String(),
        'stock_confirmed_at': confirmedAt?.toIso8601String(),
        'out_of_stock': isOutOfStock,
      };

      if (available >= 1 && available <= threshold && !isOutOfStock) {
        lowStock.add(StockAlertItem.fromJson(itemData, StockAlertType.lowStock));
      }

      if (available <= 0 || isOutOfStock) {
        outOfStock.add(StockAlertItem.fromJson(itemData, StockAlertType.outOfStock));
      }

      if (expiry != null &&
          !expiry.isBefore(today) &&
          expiry.isBefore(sixtyDaysFromNow)) {
        expiringSoon.add(StockAlertItem.fromJson(itemData, StockAlertType.expiringSoon));
      }

      if (confirmedAt == null || confirmedAt.isBefore(sevenDaysAgo)) {
        notUpdated.add(StockAlertItem.fromJson(itemData, StockAlertType.notUpdated));
      }
    }

    return {
      StockAlertType.lowStock: lowStock,
      StockAlertType.outOfStock: outOfStock,
      StockAlertType.expiringSoon: expiringSoon,
      StockAlertType.notUpdated: notUpdated,
    };
  }
}