import 'medicine.dart';

// One medicine line item inside a customer's single-branch cart
class CartItem {
  const CartItem({
    required this.branchId,
    required this.pharmacyName,
    required this.branchName,
    required this.branchAddress,
    required this.medicineId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unitSold,
    required this.isRx,
    required this.quantity,
    required this.pricePerUnit,
    required this.availability,
  });

  final String branchId;
  final String pharmacyName;
  final String branchName;
  final String branchAddress;
  final String medicineId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unitSold;
  final bool isRx;
  final int quantity;
  final double pricePerUnit;
  final MedicineAvailability availability;

  double get lineTotal => pricePerUnit * quantity;

  String get formattedUnitPrice =>
      '₱${pricePerUnit.toStringAsFixed(2)} / $unitSold';

  String get formattedLineTotal => '₱${lineTotal.toStringAsFixed(2)}';

  CartItem copyWith({int? quantity}) {
    return CartItem(
      branchId: branchId,
      pharmacyName: pharmacyName,
      branchName: branchName,
      branchAddress: branchAddress,
      medicineId: medicineId,
      brandName: brandName,
      genericName: genericName,
      strength: strength,
      dosageForm: dosageForm,
      unitSold: unitSold,
      isRx: isRx,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit,
      availability: availability,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      branchId: json['branch_id'] as String,
      pharmacyName: json['pharmacy_name'] as String,
      branchName: json['branch_name'] as String,
      branchAddress: json['branch_address'] as String,
      medicineId: json['medicine_id'] as String,
      brandName: json['brand_name'] as String,
      genericName: json['generic_name'] as String,
      strength: json['strength'] as String,
      dosageForm: json['dosage_form'] as String,
      unitSold: json['unit_sold'] as String,
      isRx: json['is_rx'] as bool? ?? false,
      quantity: (json['quantity'] as num).toInt(),
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
      availability: MedicineAvailability.fromJson(
        json['availability'] as String?,
      ),
    );
  }
}

// Prescription file uploaded to cart_prescription_files before placing reservation
class CartPrescriptionFile {
  const CartPrescriptionFile({
    required this.id,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final String id;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;

  String get fileName {
    final segments = storagePath.split('/');
    return segments.isNotEmpty ? segments.last : storagePath;
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory CartPrescriptionFile.fromJson(Map<String, dynamic> json) {
    return CartPrescriptionFile(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

// Full snapshot of the customer's cart (single branch + items + Rx uploads)
class CustomerCart {
  const CustomerCart({
    this.items = const [],
    this.prescriptions = const [],
  });

  final List<CartItem> items;
  final List<CartPrescriptionFile> prescriptions;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  String? get branchId => items.isEmpty ? null : items.first.branchId;
  String? get pharmacyName => items.isEmpty ? null : items.first.pharmacyName;
  String? get branchName => items.isEmpty ? null : items.first.branchName;
  String? get branchAddress => items.isEmpty ? null : items.first.branchAddress;

  int get totalUnits =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  String get formattedSubtotal => '₱${subtotal.toStringAsFixed(2)}';

  bool get hasRxItems => items.any((item) => item.isRx);

  bool get hasUnavailableItems =>
      items.any((item) => !item.availability.canReserve);

  // Ready to place reservation only when non-empty, all items reservable,
  // and at least one prescription file is attached if any Rx item is present.
  bool get canSubmitReservation {
    if (isEmpty || hasUnavailableItems) return false;
    if (hasRxItems && prescriptions.isEmpty) return false;
    return true;
  }

  CustomerCart withItemQuantity(String medicineId, int quantity) {
    if (quantity <= 0) {
      return CustomerCart(
        items: items.where((item) => item.medicineId != medicineId).toList(),
        prescriptions: prescriptions,
      );
    }
    return CustomerCart(
      items: items
          .map(
            (item) => item.medicineId == medicineId
                ? item.copyWith(quantity: quantity)
                : item,
          )
          .toList(),
      prescriptions: prescriptions,
    );
  }
}