// One notification for the signed-in person
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? reservationId;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = '',
    this.reservationId,
    required this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      reservationId: reservationId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String? ?? '',
      reservationId: json['reservation_id'] as String?,
      readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}