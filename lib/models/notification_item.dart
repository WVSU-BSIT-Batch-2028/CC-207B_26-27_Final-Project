/// One entry in the notification history.
/// [categoryKey] matches a toggle on the Notifications screen
/// (e.g. "appointments", "lab_results"), so turning a category off hides its items.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.categoryKey,
    required this.title,
    required this.message,
    required this.time,
    this.read = false,
  });

  final String id;
  final String categoryKey;
  final String title;
  final String message;
  final DateTime time;
  final bool read;

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        categoryKey: categoryKey,
        title: title,
        message: message,
        time: time,
        read: read ?? this.read,
      );
}
