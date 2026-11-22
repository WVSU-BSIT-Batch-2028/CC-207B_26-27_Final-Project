// Represents an item triggering a stock alert in one of the 4 categories
enum StockAlertType {
  lowStock,
  outOfStock,
  expiringSoon,
  notUpdated,
}

class StockAlertItem {
  final String id;
  final String inventoryItemId;
  final String medicineId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unit;
  final int stockQuantity;
  final int heldQuantity;
  final int lowStockThreshold;
  final DateTime? nearestExpiry;
  final DateTime? stockConfirmedAt;
  final bool outOfStock;
  final StockAlertType alertType;

  const StockAlertItem({
    required this.id,
    required this.inventoryItemId,
    required this.medicineId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unit,
    required this.stockQuantity,
    required this.heldQuantity,
    this.lowStockThreshold = 10,
    this.nearestExpiry,
    this.stockConfirmedAt,
    this.outOfStock = false,
    required this.alertType,
  });

  int get availableStock => stockQuantity - heldQuantity;

  String get medicineDisplayName {
    if (strength.isNotEmpty && strength != '—') {
      return '$brandName $strength';
    }
    return brandName;
  }

  factory StockAlertItem.fromJson(Map<String, dynamic> json, StockAlertType type) {
    return StockAlertItem(
      id: json['id']?.toString() ?? '',
      inventoryItemId: json['inventory_item_id']?.toString() ?? json['id']?.toString() ?? '',
      medicineId: json['medicine_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      strength: json['strength']?.toString() ?? '',
      dosageForm: json['dosage_form']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'unit',
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      heldQuantity: (json['held_quantity'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 10,
      nearestExpiry: json['nearest_expiry'] != null
          ? DateTime.tryParse(json['nearest_expiry'].toString())
          : null,
      stockConfirmedAt: json['stock_confirmed_at'] != null
          ? DateTime.tryParse(json['stock_confirmed_at'].toString())
          : null,
      outOfStock: json['out_of_stock'] == true,
      alertType: type,
    );
  }
}
