/// Formats a moment in Philippine time (UTC+8), for example
/// "October 26, 2026, 10:35 AM". The Philippines has no daylight saving
/// time, so a fixed 8-hour offset is always correct.
String formatPhilippineTime(DateTime moment) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Convert to UTC first, then add 8 hours, so the result does not depend
  // on the time zone of the device that is viewing the page.
  final local = moment.toUtc().add(const Duration(hours: 8));

  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';

  return '${months[local.month - 1]} ${local.day}, ${local.year}, '
      '$hour12:$minute $period';
}

/// Turns the text time saved by firestore_data.dart back into a DateTime.
/// Returns null when the value is missing, for example before staff have
/// taken that step.
DateTime? parseTime(Object? value) {
  return DateTime.tryParse((value as String?) ?? '');
}
