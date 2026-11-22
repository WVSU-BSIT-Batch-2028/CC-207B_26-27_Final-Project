import '../core/utils/date_format.dart';

/// How often the patient wants to be reminded.
enum ReminderMode {
  /// A reminder every 8 hours, starting on the start date.
  every8Hours,

  /// One reminder a day at a time the patient picks.
  customTime,
}

/// A saved reminder for one prescription.
///
/// Plain data plus `toJson` / `fromJson`, so the service can save it as text
/// in shared_preferences and read it back later.
class ReminderSetting {
  const ReminderSetting({
    required this.prescriptionId,
    required this.mode,
    required this.startDate,
    required this.notificationsEnabled,
    this.customHour,
    this.customMinute,
  });

  /// Which prescription the reminder is for (matches `Prescription.id`).
  final String prescriptionId;

  /// Every 8 hours, or a custom daily time.
  final ReminderMode mode;

  /// First day the reminder applies (date only).
  final DateTime startDate;

  /// The "Enable Notifications" switch.
  final bool notificationsEnabled;

  /// Hour (0-23) and minute (0-59) of the daily reminder.
  /// Only used when [mode] is [ReminderMode.customTime].
  final int? customHour;
  final int? customMinute;

  /// Short text used in the confirmation message,
  /// e.g. "every 8 hours" or "daily at 8:00 AM".
  String get summary {
    switch (mode) {
      case ReminderMode.every8Hours:
        return 'every 8 hours';
      case ReminderMode.customTime:
        final hour = customHour ?? 8;
        final minute = customMinute ?? 0;
        return 'daily at ${formatTime(DateTime(2000, 1, 1, hour, minute))}';
    }
  }

  /// Turns the reminder into a map that can be saved as JSON text.
  Map<String, dynamic> toJson() => {
        'prescriptionId': prescriptionId,
        'mode': mode.name,
        'startDate': dateKey(startDate),
        'notificationsEnabled': notificationsEnabled,
        'customHour': customHour,
        'customMinute': customMinute,
      };

  /// Rebuilds a reminder from saved JSON.
  /// Throws if the data is damaged; the service catches that.
  factory ReminderSetting.fromJson(Map<String, dynamic> json) {
    return ReminderSetting(
      prescriptionId: json['prescriptionId'] as String,
      mode: ReminderMode.values.byName(json['mode'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      notificationsEnabled: json['notificationsEnabled'] as bool,
      customHour: json['customHour'] as int?,
      customMinute: json['customMinute'] as int?,
    );
  }
}
