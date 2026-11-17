// One pharmacy event that only the branch owner can see
class ActivityLogEntry {
  final int id;
  final String actorLabel;
  final String? actorRole;
  final String action;
  final String? entityType;
  final String? entityId;
  final DateTime createdAt;

  const ActivityLogEntry({
    required this.id,
    required this.actorLabel,
    this.actorRole,
    required this.action,
    this.entityType,
    this.entityId,
    required this.createdAt,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] as int,
      actorLabel: json['actor_label'] as String,
      actorRole: json['actor_role'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}