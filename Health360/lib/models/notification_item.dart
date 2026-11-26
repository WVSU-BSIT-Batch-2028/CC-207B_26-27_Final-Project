/// The screen a notification opens when it is tapped.
enum NotificationTarget {
  /// Doctor: Menu > Prescriptions (refill requests are answered there).
  doctorPrescriptions,

  /// Patient: the details of one prescription (see [NotificationItem.targetId]).
  prescriptionDetails,
}

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
    this.target,
    this.targetId,
  });

  final String id;
  final String categoryKey;
  final String title;
  final String message;
  final DateTime time;
  final bool read;

  /// Which screen tapping the notification opens. Null for notifications
  /// that only get marked as read.
  final NotificationTarget? target;

  /// Extra id the [target] needs (the prescription id for
  /// [NotificationTarget.prescriptionDetails]).
  final String? targetId;

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        categoryKey: categoryKey,
        title: title,
        message: message,
        time: time,
        read: read ?? this.read,
        target: target,
        targetId: targetId,
      );
}