// Availability label reported for a medicine at a pharmacy
enum MedicineAvailability {
  available,
  lowStock,
  unavailable,
  unconfirmed;

  // Parses the database availability_status enum string
  static MedicineAvailability fromJson(String? value) {
    switch (value) {
      case 'available':
        return MedicineAvailability.available;
      case 'low_stock':
        return MedicineAvailability.lowStock;
      case 'unconfirmed':
        return MedicineAvailability.unconfirmed;
      case 'unavailable':
      default:
        return MedicineAvailability.unavailable;
    }
  }

  // Only Available and Low Stock items can be added to the cart
  bool get canReserve =>
      this == MedicineAvailability.available ||
      this == MedicineAvailability.lowStock;

  // Button label on offer / inventory cards
  String get cartActionLabel => switch (this) {
        MedicineAvailability.available || MedicineAvailability.lowStock =>
          'Add to Cart',
        MedicineAvailability.unconfirmed => 'Unconfirmed',
        MedicineAvailability.unavailable => 'Unavailable',
      };
}

// Grouped medicine row returned by search_medicines
class MedicineSearchResult {
  const MedicineSearchResult({
    required this.medicineId,
    required this.displayId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unitSold,
    required this.isRx,
    required this.lowestPrice,
    required this.pharmacyCount,
    this.nearestKm,
    this.imagePath,
  });

  final String medicineId;
  final String displayId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unitSold;
  final bool isRx;
  final double lowestPrice;
  final int pharmacyCount;
  final double? nearestKm;
  final String? imagePath;

  String get formattedLowestPrice =>
      'From ₱${lowestPrice.toStringAsFixed(2)} / $unitSold';

  factory MedicineSearchResult.fromJson(Map<String, dynamic> json) {
    return MedicineSearchResult(
      medicineId: json['medicine_id'] as String,
      displayId: json['display_id'] as String? ?? '',
      brandName: json['brand_name'] as String,
      genericName: json['generic_name'] as String,
      strength: json['strength'] as String,
      dosageForm: json['dosage_form'] as String,
      unitSold: json['unit_sold'] as String,
      isRx: json['is_rx'] as bool? ?? false,
      lowestPrice: (json['lowest_price'] as num).toDouble(),
      pharmacyCount: (json['pharmacy_count'] as num).toInt(),
      nearestKm: (json['nearest_km'] as num?)?.toDouble(),
      imagePath: json['image_path'] as String?,
    );
  }
}

// Pharmacy offer row returned by get_medicine_offers
class MedicineOffer {
  const MedicineOffer({
    required this.inventoryId,
    required this.branchId,
    required this.branchDisplayId,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.pricePerUnit,
    required this.availability,
    required this.stockConfirmedAt,
    this.distanceKm,
  });

  final String inventoryId;
  final String branchId;
  final String branchDisplayId;
  final String pharmacyName;
  final String branchName;
  final String address;
  final double pricePerUnit;
  final MedicineAvailability availability;
  final DateTime stockConfirmedAt;
  final double? distanceKm;

  factory MedicineOffer.fromJson(Map<String, dynamic> json) {
    return MedicineOffer(
      inventoryId: json['inventory_id'] as String,
      branchId: json['branch_id'] as String,
      branchDisplayId: json['branch_display_id'] as String? ?? '',
      pharmacyName: json['pharmacy_name'] as String,
      branchName: json['branch_name'] as String,
      address: json['address'] as String,
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      availability: MedicineAvailability.fromJson(
        json['availability'] as String?,
      ),
      stockConfirmedAt: DateTime.parse(json['stock_confirmed_at'] as String),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}