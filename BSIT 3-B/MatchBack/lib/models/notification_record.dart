import '../utils/date_format.dart';

/// One time staff tried to contact a student about a claim.
/// It stores no contact details, only what happened and when.
class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.claimId,
    required this.event,
    required this.method,
    required this.outcome,
    this.sentAt,
  });

  final String id;
  final String claimId;

  /// 'approved' or 'ready'.
  final String event;

  /// 'email', 'phone' or 'text'.
  final String method;

  /// 'contacted' or 'failed'.
  final String outcome;

  /// Server time of the attempt.
  final DateTime? sentAt;

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String,
      claimId: json['claimId'] as String,
      event: json['event'] as String,
      method: json['method'] as String,
      outcome: json['outcome'] as String,
      sentAt: parseTime(json['sentAt']),
    );
  }
}
