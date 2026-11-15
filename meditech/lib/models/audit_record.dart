// One platform event that only administrators can see
class AuditRecord {
  final String id;
  final String displayId;
  final String actorLabel;
  final String? actorRole;
  final String eventType;
  final String action;
  final String? recordRef;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AuditRecord({
    required this.id,
    required this.displayId,
    required this.actorLabel,
    this.actorRole,
    required this.eventType,
    required this.action,
    this.recordRef,
    required this.details,
    required this.createdAt,
  });

  factory AuditRecord.fromJson(Map<String, dynamic> json) {
    final details = json['details'];
    return AuditRecord(
      id: json['id'] as String,
      displayId: json['display_id'] as String,
      actorLabel: json['actor_label'] as String,
      actorRole: json['actor_role'] as String?,
      eventType: json['event_type'] as String,
      action: json['action'] as String,
      recordRef: json['record_ref'] as String?,
      details: details is Map ? Map<String, dynamic>.from(details) : {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}