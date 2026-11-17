// One recorded FDA check
class VerificationCheck {
  const VerificationCheck({
    required this.id,
    required this.checkedNumber,
    required this.result,
    this.notes,
    required this.checkedByLabel,
    required this.checkedAt,
  });

  final String id;
  final String checkedNumber; // the LTO number checked
  final String result; // matched, not_found, details_mismatch, expired, unreadable
  final String? notes;
  final String checkedByLabel; // the admin's name
  final DateTime checkedAt;

  factory VerificationCheck.fromJson(Map<String, dynamic> json) => VerificationCheck(
        id: json['id'] as String,
        checkedNumber: json['checked_number'] as String,
        result: json['result'] as String,
        notes: json['notes'] as String?,
        checkedByLabel: json['checked_by_label'] as String,
        checkedAt: DateTime.parse(json['checked_at'] as String).toLocal(),
      );
}