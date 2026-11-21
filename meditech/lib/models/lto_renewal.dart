// A renewed License to Operate sent by a suspended owner
class LtoRenewal {
  const LtoRenewal({
    required this.id,
    required this.ltoNumber,
    required this.ltoExpiry,
    required this.storagePath,
    required this.mimeType,
    required this.status,
    this.reviewReason,
    required this.createdAt,
  });

  final String id;
  final String ltoNumber;
  final DateTime ltoExpiry;
  final String storagePath;
  final String mimeType;
  final String status; // pending, accepted, rejected
  final String? reviewReason;
  final DateTime createdAt;

  bool get isImage => mimeType.startsWith('image/');

  factory LtoRenewal.fromJson(Map<String, dynamic> json) => LtoRenewal(
        id: json['id'] as String,
        ltoNumber: json['lto_number'] as String,
        ltoExpiry: DateTime.parse(json['lto_expiry'] as String),
        storagePath: json['storage_path'] as String,
        mimeType: json['mime_type'] as String,
        status: json['status'] as String,
        reviewReason: json['review_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

// The owner's own pharmacy, as seen while it's offline
class OwnBranch {
  const OwnBranch({
    required this.id,
    required this.displayId,
    required this.pharmacyName,
    required this.branchName,
    required this.status,
    this.deactivationReason,
    required this.ltoNumber,
    required this.ltoExpiry,
  });

  final String id;
  final String displayId;
  final String pharmacyName;
  final String branchName;
  final String status;
  final String? deactivationReason;
  final String ltoNumber;
  final DateTime ltoExpiry;

  factory OwnBranch.fromJson(Map<String, dynamic> json) => OwnBranch(
        id: json['id'] as String,
        displayId: json['display_id'] as String,
        pharmacyName: json['pharmacy_name'] as String,
        branchName: json['branch_name'] as String,
        status: json['status'] as String,
        deactivationReason: json['deactivation_reason'] as String?,
        ltoNumber: json['lto_number'] as String,
        ltoExpiry: DateTime.parse(json['lto_expiry'] as String),
      );
}