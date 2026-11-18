// One row in the admin pharmacies table
class PharmacySummary {
  const PharmacySummary({
    required this.id,
    required this.displayId,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.ownerName,
    required this.ltoNumber,
    required this.ltoExpiry,
    required this.status,
    required this.submittedAt,
    required this.possibleDuplicate,
  });

  final String id;
  final String displayId;
  final String pharmacyName;
  final String branchName;
  final String address;
  final String? ownerName;
  final String ltoNumber;
  final DateTime ltoExpiry;
  final String status; // pending_approval, active, inactive, rejected
  final DateTime submittedAt;
  final bool possibleDuplicate;

  factory PharmacySummary.fromJson(Map<String, dynamic> json) => PharmacySummary(
        id: json['id'] as String,
        displayId: json['display_id'] as String,
        pharmacyName: json['pharmacy_name'] as String,
        branchName: json['branch_name'] as String,
        address: json['address'] as String,
        ownerName: json['owner_name'] as String?,
        ltoNumber: json['lto_number'] as String,
        ltoExpiry: DateTime.parse(json['lto_expiry'] as String),
        status: json['status'] as String,
        submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
        possibleDuplicate: json['possible_duplicate'] as bool? ?? false,
      );
}