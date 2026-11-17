// One medicine a pharmacy branch stocks, with its price and stock count
class InventoryItem {
  final String id;
  final String displayId;
  final String medicineId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unit;
  final bool isRx;
  final int stockQuantity;
  final int heldQuantity;
  final double pricePerUnit;
  final int lowStockThreshold;
  final DateTime? nearestExpiry;
  final bool outOfStock;
  final bool isActive;
  final DateTime stockConfirmedAt;

  const InventoryItem({
    required this.id,
    required this.displayId,
    required this.medicineId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unit,
    required this.isRx,
    required this.stockQuantity,
    required this.heldQuantity,
    required this.pricePerUnit,
    required this.lowStockThreshold,
    this.nearestExpiry,
    required this.outOfStock,
    required this.isActive,
    required this.stockConfirmedAt,
  });

  // Units a customer could still reserve
  int get availableQuantity => stockQuantity - heldQuantity;

  // The label customers see, in the agreed order
  String get availability {
    if (outOfStock) return 'Unavailable';
    if (availableQuantity <= 0) return 'Unavailable';
    if (stockConfirmedAt
        .isBefore(DateTime.now().subtract(const Duration(days: 7)))) {
      return 'Unconfirmed';
    }
    if (availableQuantity <= lowStockThreshold) return 'Low Stock';
    return 'Available';
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final medicine = json['medicines'] as Map<String, dynamic>;
    final form = medicine['dosage_forms'] as Map<String, dynamic>;
    final unit = medicine['units'] as Map<String, dynamic>;
    final expiry = json['nearest_expiry'] as String?;
    return InventoryItem(
      id: json['id'] as String,
      displayId: json['display_id'] as String,
      medicineId: json['medicine_id'] as String,
      brandName: medicine['brand_name'] as String,
      genericName: medicine['generic_name'] as String,
      strength: medicine['strength'] as String,
      dosageForm: form['name'] as String,
      unit: unit['name'] as String,
      isRx: medicine['is_rx'] as bool,
      stockQuantity: json['stock_quantity'] as int,
      heldQuantity: json['held_quantity'] as int,
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      lowStockThreshold: json['low_stock_threshold'] as int,
      nearestExpiry: expiry == null ? null : DateTime.parse(expiry),
      outOfStock: json['out_of_stock_flag'] as bool,
      isActive: json['is_active'] as bool,
      stockConfirmedAt: DateTime.parse(json['stock_confirmed_at'] as String),
    );
  }
}

// A catalogue medicine a pharmacy can pick when adding inventory
class CatalogueMedicine {
  final String id;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unit;
  final bool isRx;

  const CatalogueMedicine({
    required this.id,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unit,
    required this.isRx,
  });

  String get label => '$brandName $strength';

  factory CatalogueMedicine.fromJson(Map<String, dynamic> json) {
    final form = json['dosage_forms'] as Map<String, dynamic>;
    final unit = json['units'] as Map<String, dynamic>;
    return CatalogueMedicine(
      id: json['id'] as String,
      brandName: json['brand_name'] as String,
      genericName: json['generic_name'] as String,
      strength: json['strength'] as String,
      dosageForm: form['name'] as String,
      unit: unit['name'] as String,
      isRx: json['is_rx'] as bool,
    );
  }
}