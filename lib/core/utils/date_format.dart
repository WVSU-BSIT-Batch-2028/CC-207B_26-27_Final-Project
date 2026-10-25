/// Tiny date helpers (kept dependency-free on purpose).

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

const List<String> _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// 10:00 AM
String formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

/// Thursday, September 10
String formatWeekdayDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// Morning / Afternoon / Evening based on the hour.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good Morning';
  if (now.hour < 18) return 'Good Afternoon';
  return 'Good Evening';
}

/// Today / Tomorrow / In 3 days (calendar-day based).
String relativeDayLabel(DateTime target, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(target.year, target.month, target.day);
  final diff = day.difference(today).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return 'In $diff days';
}

/// yyyy-mm-dd, used as a storage key.
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// September 10, 2026
String formatLongDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Oct 23
String formatShortDate(DateTime d) => '${_monthsShort[d.month - 1]} ${d.day}';

/// Mon, Tue, ...
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// "Today, 9:00 AM" / "Yesterday, 4:30 PM" / "Oct 21, 11:15 AM"
String formatActivityTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Today, ${formatTime(t)}';
  if (diff == 1) return 'Yesterday, ${formatTime(t)}';
  return '${formatShortDate(t)}, ${formatTime(t)}';
}
