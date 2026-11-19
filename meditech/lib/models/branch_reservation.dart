// A reservation placed by a customer at this pharmacy branch
class BranchReservationItem {
  final int lineNo;
  final String medicineId;
  final String inventoryItemId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unitSold;
  final bool isRx;
  final double unitPrice;
  final int quantity;
  final int heldQuantity;
  final int? currentAvailableStock;

  const BranchReservationItem({
    required this.lineNo,
    required this.medicineId,
    required this.inventoryItemId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unitSold,
    required this.isRx,
    required this.unitPrice,
    required this.quantity,
    required this.heldQuantity,
    this.currentAvailableStock,
  });

  factory BranchReservationItem.fromJson(Map<String, dynamic> json) {
    return BranchReservationItem(
      lineNo: (json['line_no'] as num?)?.toInt() ?? 1,
      medicineId: json['medicine_id'] as String? ?? '',
      inventoryItemId: json['inventory_item_id'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? '',
      genericName: json['generic_name'] as String? ?? '',
      strength: json['strength'] as String? ?? '',
      dosageForm: json['dosage_form'] as String? ?? '',
      unitSold: json['unit_sold'] as String? ?? '',
      isRx: json['is_rx'] as bool? ?? false,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      heldQuantity: (json['held_quantity'] as num?)?.toInt() ?? 0,
      currentAvailableStock: (json['current_available_stock'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'line_no': lineNo,
      'medicine_id': medicineId,
      'inventory_item_id': inventoryItemId,
      'brand_name': brandName,
      'generic_name': genericName,
      'strength': strength,
      'dosage_form': dosageForm,
      'unit_sold': unitSold,
      'is_rx': isRx,
      'unit_price': unitPrice,
      'quantity': quantity,
      'held_quantity': heldQuantity,
      'current_available_stock': currentAvailableStock,
    };
  }

  BranchReservationItem copyWith({
    int? lineNo,
    String? medicineId,
    String? inventoryItemId,
    String? brandName,
    String? genericName,
    String? strength,
    String? dosageForm,
    String? unitSold,
    bool? isRx,
    double? unitPrice,
    int? quantity,
    int? heldQuantity,
    int? currentAvailableStock,
  }) {
    return BranchReservationItem(
      lineNo: lineNo ?? this.lineNo,
      medicineId: medicineId ?? this.medicineId,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      brandName: brandName ?? this.brandName,
      genericName: genericName ?? this.genericName,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      unitSold: unitSold ?? this.unitSold,
      isRx: isRx ?? this.isRx,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      heldQuantity: heldQuantity ?? this.heldQuantity,
      currentAvailableStock:
          currentAvailableStock ?? this.currentAvailableStock,
    );
  }
}

// A status change event in the reservation history
class BranchReservationHistory {
  final int? id;
  final String? fromStatus;
  final String toStatus;
  final String? actorRole;
  final String? actorName;
  final String? reason;
  final DateTime createdAt;

  const BranchReservationHistory({
    this.id,
    this.fromStatus,
    required this.toStatus,
    this.actorRole,
    this.actorName,
    this.reason,
    required this.createdAt,
  });

  factory BranchReservationHistory.fromJson(Map<String, dynamic> json) {
    return BranchReservationHistory(
      id: (json['id'] as num?)?.toInt(),
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String? ?? 'pending',
      actorRole: json['actor_role'] as String?,
      actorName: json['actor_name'] as String?,
      reason: json['reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_status': fromStatus,
      'to_status': toStatus,
      'actor_role': actorRole,
      'actor_name': actorName,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Uploaded doctor's prescription attached to a reservation
class BranchPrescription {
  final String id;
  final String displayId;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;

  const BranchPrescription({
    required this.id,
    required this.displayId,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory BranchPrescription.fromJson(Map<String, dynamic> json) {
    return BranchPrescription(
      id: json['id'] as String? ?? '',
      displayId: json['display_id'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'image/jpeg',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_id': displayId,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

// Complete reservation view for pharmacy tablet operations
class BranchReservation {
  final String id;
  final String referenceNo;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String branchId;
  final String status;
  final bool hasRx;
  final double totalAmount;
  final DateTime submittedAt;
  final DateTime expiresAt;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final String? closedReason;
  final String? pickupCodeSuffix;
  final List<BranchReservationItem> items;
  final List<BranchReservationHistory> history;
  final List<BranchPrescription> prescriptions;

  const BranchReservation({
    required this.id,
    required this.referenceNo,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.branchId,
    required this.status,
    required this.hasRx,
    required this.totalAmount,
    required this.submittedAt,
    required this.expiresAt,
    this.confirmedAt,
    this.readyAt,
    this.completedAt,
    this.closedReason,
    this.pickupCodeSuffix,
    this.items = const [],
    this.history = const [],
    this.prescriptions = const [],
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isReady => status == 'ready_for_pickup';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';

  // Summary string shown in data table column, e.g. "Biogesic x 20 + 1 more"
  String get medicinesSummary {
    if (items.isEmpty) return 'No items';
    final first = items.first;
    final firstLabel = '${first.brandName} × ${first.quantity}';
    if (items.length == 1) return firstLabel;
    final extra = items.length - 1;
    return '$firstLabel + $extra more';
  }

  factory BranchReservation.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((i) => BranchReservationItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final rawHistory = json['history'] as List<dynamic>? ?? [];
    final historyList = rawHistory
        .map((h) => BranchReservationHistory.fromJson(h as Map<String, dynamic>))
        .toList();

    final rawPrescriptions = json['prescriptions'] as List<dynamic>? ?? [];
    final prescriptionsList = rawPrescriptions
        .map((p) => BranchPrescription.fromJson(p as Map<String, dynamic>))
        .toList();

    return BranchReservation(
      id: json['id'] as String? ?? '',
      referenceNo: json['reference_no'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String?,
      branchId: json['branch_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      hasRx: json['has_rx'] as bool? ?? false,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      readyAt: json['ready_at'] != null
          ? DateTime.parse(json['ready_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      closedReason: json['closed_reason'] as String?,
      pickupCodeSuffix: json['pickup_code_suffix'] as String?,
      items: itemsList,
      history: historyList,
      prescriptions: prescriptionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_no': referenceNo,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'branch_id': branchId,
      'status': status,
      'has_rx': hasRx,
      'total_amount': totalAmount,
      'submitted_at': submittedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'ready_at': readyAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'closed_reason': closedReason,
      'pickup_code_suffix': pickupCodeSuffix,
      'items': items.map((i) => i.toJson()).toList(),
      'history': history.map((h) => h.toJson()).toList(),
      'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
    };
  }

  BranchReservation copyWith({
    String? id,
    String? referenceNo,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? branchId,
    String? status,
    bool? hasRx,
    double? totalAmount,
    DateTime? submittedAt,
    DateTime? expiresAt,
    DateTime? confirmedAt,
    DateTime? readyAt,
    DateTime? completedAt,
    String? closedReason,
    String? pickupCodeSuffix,
    List<BranchReservationItem>? items,
    List<BranchReservationHistory>? history,
    List<BranchPrescription>? prescriptions,
  }) {
    return BranchReservation(
      id: id ?? this.id,
      referenceNo: referenceNo ?? this.referenceNo,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      hasRx: hasRx ?? this.hasRx,
      totalAmount: totalAmount ?? this.totalAmount,
      submittedAt: submittedAt ?? this.submittedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      readyAt: readyAt ?? this.readyAt,
      completedAt: completedAt ?? this.completedAt,
      closedReason: closedReason ?? this.closedReason,
      pickupCodeSuffix: pickupCodeSuffix ?? this.pickupCodeSuffix,
      items: items ?? this.items,
      history: history ?? this.history,
      prescriptions: prescriptions ?? this.prescriptions,
    );
  }
}
