// A pharmacy's request for a medicine that isn't in the catalogue yet
class MedicineRequest {
  const MedicineRequest({
    required this.id,
    required this.displayId,
    required this.genericName,
    this.brandName,
    this.strength,
    this.dosageForm,
    this.registrationNumber,
    this.notes,
    required this.status,
    this.dismissReason,
    required this.pharmacyName,
    required this.branchName,
    required this.requestedBy,
    required this.createdAt,
  });

  final String id;
  final String displayId; // like REQ-000001
  final String genericName;
  final String? brandName;
  final String? strength;
  final String? dosageForm;
  final String? registrationNumber;
  final String? notes;
  final String status; // open, added, dismissed
  final String? dismissReason;
  final String pharmacyName;
  final String branchName;
  final String requestedBy;
  final DateTime createdAt;

  // "Keflex · 500 mg · Capsule", skipping blanks
  String get details => [brandName, strength, dosageForm].whereType<String>().join(' · ');

  factory MedicineRequest.fromJson(Map<String, dynamic> json) => MedicineRequest(
        id: json['id'] as String,
        displayId: json['display_id'] as String,
        genericName: json['generic_name'] as String,
        brandName: json['brand_name'] as String?,
        strength: json['strength'] as String?,
        dosageForm: json['dosage_form'] as String?,
        registrationNumber: json['registration_number'] as String?,
        notes: json['notes'] as String?,
        status: json['status'] as String,
        dismissReason: json['dismiss_reason'] as String?,
        pharmacyName: json['pharmacy_name'] as String,
        branchName: json['branch_name'] as String,
        requestedBy: json['requested_by_label'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}