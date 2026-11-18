import 'package:intl/intl.dart';

// Reservation lifecycle statuses matching PostgreSQL reservation_status enum
enum ReservationStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  readyForPickup('ready_for_pickup', 'Ready for Pickup'),
  completed('completed', 'Completed'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled'),
  expired('expired', 'Expired');

  const ReservationStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isActive =>
      this == pending || this == confirmed || this == readyForPickup;

  static ReservationStatus fromJson(String? value) {
    return ReservationStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => ReservationStatus.pending,
    );
  }
}

// Returned immediately by submit_reservation RPC
class SubmittedReservationResult {
  const SubmittedReservationResult({
    required this.reservationId,
    required this.referenceNo,
  });

  final String reservationId;
  final String referenceNo;

  factory SubmittedReservationResult.fromJson(Map<String, dynamic> json) {
    return SubmittedReservationResult(
      reservationId: json['reservation_id'] as String,
      referenceNo: json['reference_no'] as String,
    );
  }
}

// Snapshot of a medicine item inside a placed reservation
class ReservationItem {
  const ReservationItem({
    required this.lineNo,
    required this.medicineId,
    required this.quantity,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unitSold,
    required this.isRx,
    required this.unitPrice,
  });

  final int lineNo;
  final String medicineId;
  final int quantity;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unitSold;
  final bool isRx;
  final double unitPrice;

  double get lineTotal => unitPrice * quantity;

  String get formattedUnitPrice =>
      '₱${unitPrice.toStringAsFixed(2)} / $unitSold (price at submission)';

  String get formattedLineTotal => '₱${lineTotal.toStringAsFixed(2)}';

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    return ReservationItem(
      lineNo: (json['line_no'] as num).toInt(),
      medicineId: json['medicine_id'] as String,
      quantity: (json['quantity'] as num).toInt(),
      brandName: json['brand_name'] as String,
      genericName: json['generic_name'] as String,
      strength: json['strength'] as String,
      dosageForm: json['dosage_form'] as String,
      unitSold: json['unit_sold'] as String,
      isRx: json['is_rx'] as bool? ?? false,
      unitPrice: (json['unit_price'] as num).toDouble(),
    );
  }
}

// One step in the vertical status timeline on Reservation Details
class ReservationStatusEvent {
  const ReservationStatusEvent({
    required this.id,
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.actorRole,
    this.reason,
  });

  final int id;
  final ReservationStatus? fromStatus;
  final ReservationStatus toStatus;
  final String? actorRole;
  final String? reason;
  final DateTime createdAt;

  factory ReservationStatusEvent.fromJson(Map<String, dynamic> json) {
    return ReservationStatusEvent(
      id: (json['id'] as num).toInt(),
      fromStatus: json['from_status'] == null
          ? null
          : ReservationStatus.fromJson(json['from_status'] as String?),
      toStatus: ReservationStatus.fromJson(json['to_status'] as String?),
      actorRole: json['actor_role'] as String?,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Prescription attachment linked to a placed reservation
class ReservationPrescription {
  const ReservationPrescription({
    required this.id,
    required this.displayId,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final String id;
  final String displayId;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;

  String get fileName {
    final segments = storagePath.split('/');
    return segments.isNotEmpty ? segments.last : storagePath;
  }

  factory ReservationPrescription.fromJson(Map<String, dynamic> json) {
    return ReservationPrescription(
      id: json['id'] as String,
      displayId: json['display_id'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

// Customer-facing reservation record with items, pickup code, and timeline
class CustomerReservation {
  const CustomerReservation({
    required this.id,
    required this.referenceNo,
    required this.branchId,
    required this.pharmacyName,
    required this.branchName,
    required this.branchAddress,
    required this.status,
    required this.hasRx,
    required this.totalAmount,
    required this.submittedAt,
    required this.expiresAt,
    required this.updatedAt,
    this.confirmedAt,
    this.readyAt,
    this.completedAt,
    this.closedReason,
    this.pickupCodeSuffix,
    this.items = const [],
    this.statusHistory = const [],
    this.prescriptions = const [],
  });

  final String id;
  final String referenceNo;
  final String branchId;
  final String pharmacyName;
  final String branchName;
  final String branchAddress;
  final ReservationStatus status;
  final bool hasRx;
  final double totalAmount;
  final DateTime submittedAt;
  final DateTime expiresAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final String? closedReason;
  final String? pickupCodeSuffix;
  final List<ReservationItem> items;
  final List<ReservationStatusEvent> statusHistory;
  final List<ReservationPrescription> prescriptions;

  String get formattedTotal => '₱${totalAmount.toStringAsFixed(2)}';

  // Full pickup code (MT-MMDDYY-XXXX) shown after pharmacy confirms
  String? get fullPickupCode {
    if (pickupCodeSuffix == null || pickupCodeSuffix!.isEmpty) return null;
    final datePart = DateFormat('MMddyy').format(submittedAt.toLocal());
    return 'MT-$datePart-$pickupCodeSuffix';
  }

  // Short summary like "Amoxil × 1" or "Biogesic × 20 + 1 more"
  String get medicinesSummary {
    if (items.isEmpty) return 'No items';
    final first = '${items.first.brandName} × ${items.first.quantity}';
    if (items.length == 1) return first;
    return '$first + ${items.length - 1} more';
  }

  factory CustomerReservation.fromJson(Map<String, dynamic> json) {
    final branch = json['branches'] as Map<String, dynamic>? ?? const {};
    final rawItems = json['reservation_items'] as List<dynamic>? ?? const [];
    final rawHistory =
        json['reservation_status_history'] as List<dynamic>? ?? const [];
    final rawPrescriptions =
        json['reservation_prescriptions'] as List<dynamic>? ?? const [];

    String? suffix;
    final rawPickup = json['pickup_codes'];
    if (rawPickup is Map<String, dynamic>) {
      suffix = rawPickup['code_suffix'] as String?;
    } else if (rawPickup is List && rawPickup.isNotEmpty) {
      suffix = (rawPickup.first as Map<String, dynamic>)['code_suffix'] as String?;
    }

    final parsedItems = rawItems
        .map((row) => ReservationItem.fromJson(row as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.lineNo.compareTo(b.lineNo));

    final parsedHistory = rawHistory
        .map(
          (row) => ReservationStatusEvent.fromJson(row as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final parsedPrescriptions = rawPrescriptions
        .map(
          (row) => ReservationPrescription.fromJson(row as Map<String, dynamic>),
        )
        .toList();

    return CustomerReservation(
      id: json['id'] as String,
      referenceNo: json['reference_no'] as String,
      branchId: json['branch_id'] as String,
      pharmacyName: branch['pharmacy_name'] as String? ?? 'Pharmacy',
      branchName: branch['branch_name'] as String? ?? '',
      branchAddress: branch['address'] as String? ?? '',
      status: ReservationStatus.fromJson(json['status'] as String?),
      hasRx: json['has_rx'] as bool? ?? false,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      confirmedAt: json['confirmed_at'] == null
          ? null
          : DateTime.parse(json['confirmed_at'] as String),
      readyAt: json['ready_at'] == null
          ? null
          : DateTime.parse(json['ready_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      closedReason: json['closed_reason'] as String?,
      pickupCodeSuffix: suffix,
      items: parsedItems,
      statusHistory: parsedHistory,
      prescriptions: parsedPrescriptions,
    );
  }
}