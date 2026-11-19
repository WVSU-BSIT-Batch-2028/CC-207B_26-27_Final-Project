// The state of a pharmacy's application, as the owner sees it
class ApplicationStatus {
  const ApplicationStatus({
    required this.displayId,
    required this.pharmacyName,
    required this.branchName,
    required this.status,
    required this.submittedAt,
    this.approvedAt,
    this.rejectionReason,
  });

  final String displayId; // like PHM-000008
  final String pharmacyName;
  final String branchName;
  final String status; // pending_approval, rejected, active, inactive
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final String? rejectionReason;

  factory ApplicationStatus.fromJson(Map<String, dynamic> json) => ApplicationStatus(
        displayId: json['display_id'] as String,
        pharmacyName: json['pharmacy_name'] as String,
        branchName: json['branch_name'] as String,
        status: json['status'] as String,
        submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
        approvedAt: json['approved_at'] == null
            ? null
            : DateTime.parse(json['approved_at'] as String).toLocal(),
        rejectionReason: json['rejection_reason'] as String?,
      );
}