/// Formats a local [date] as an ISO calendar date string (`YYYY-MM-DD`).
String formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Returns today's local calendar date formatted as `YYYY-MM-DD`.
String todayIsoDate() => formatIsoDate(DateTime.now());
