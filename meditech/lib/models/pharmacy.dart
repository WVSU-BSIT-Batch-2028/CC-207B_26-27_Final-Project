import 'medicine.dart';

// Approved pharmacy branch details returned by get_pharmacy_details
class PharmacyDetail {
  const PharmacyDetail({
    required this.branchId,
    required this.displayId,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.contactNumber,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });

  final String branchId;
  final String displayId;
  final String pharmacyName;
  final String branchName;
  final String address;
  final String contactNumber;
  final double latitude;
  final double longitude;
  final double? distanceKm;

  factory PharmacyDetail.fromJson(Map<String, dynamic> json) {
    return PharmacyDetail(
      branchId: '${json['branch_id'] ?? json['id']}',
      displayId: json['display_id'] as String? ?? '',
      pharmacyName: json['pharmacy_name'] as String? ?? 'Pharmacy',
      branchName: json['branch_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      contactNumber: json['contact_number'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}

// Weekly opening hours row returned by get_pharmacy_hours (0 = Sunday .. 6 = Saturday)
class PharmacyHours {
  const PharmacyHours({
    required this.weekday,
    this.opensAt,
    this.closesAt,
    required this.isClosed,
  });

  final int weekday;
  final String? opensAt;
  final String? closesAt;
  final bool isClosed;

  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String get dayLabel =>
      (weekday >= 0 && weekday < _dayNames.length) ? _dayNames[weekday] : '';

  String get scheduleLabel {
    if (isClosed || opensAt == null || closesAt == null) return 'Closed';
    return '${_formatTime(opensAt!)} – ${_formatTime(closesAt!)}';
  }

  // Formats HH:mm:ss Postgres time into 12-hour display (e.g. 8:00 AM)
  static String _formatTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  factory PharmacyHours.fromJson(Map<String, dynamic> json) {
    return PharmacyHours(
      weekday: (json['weekday'] as num).toInt(),
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }
}

// Medicine offering at a specific branch returned by get_pharmacy_inventory
class PharmacyInventoryItem {
  const PharmacyInventoryItem({
    required this.inventoryId,
    required this.medicineId,
    required this.medicineDisplayId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unitSold,
    this.packDescription,
    required this.isRx,
    required this.pricePerUnit,
    required this.availability,
    required this.stockConfirmedAt,
  });

  final String inventoryId;
  final String medicineId;
  final String medicineDisplayId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unitSold;
  final String? packDescription;
  final bool isRx;
  final double pricePerUnit;
  final MedicineAvailability availability;
  final DateTime stockConfirmedAt;

  String get formattedPrice =>
      '₱${pricePerUnit.toStringAsFixed(2)} / $unitSold';

  factory PharmacyInventoryItem.fromJson(Map<String, dynamic> json) {
    return PharmacyInventoryItem(
      inventoryId: json['inventory_id'] as String,
      medicineId: json['medicine_id'] as String,
      medicineDisplayId: json['medicine_display_id'] as String? ?? '',
      brandName: json['brand_name'] as String,
      genericName: json['generic_name'] as String,
      strength: json['strength'] as String,
      dosageForm: json['dosage_form'] as String,
      unitSold: json['unit_sold'] as String,
      packDescription: json['pack_description'] as String?,
      isRx: json['is_rx'] as bool? ?? false,
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      availability: MedicineAvailability.fromJson(
        json['availability'] as String?,
      ),
      stockConfirmedAt: DateTime.parse(json['stock_confirmed_at'] as String),
    );
  }
}