// Class times are wall-clock times in Asia/Manila (UTC+8, no daylight saving), independent of the
// device's own time zone.
const _offset = Duration(hours: 8);
const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Manila wall clock for an instant (fields read as UTC).
DateTime manila(DateTime instant) => instant.toUtc().add(_offset);

int toMinutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

DateTime _instant(DateTime manilaDay, int minutes) =>
    DateTime.utc(manilaDay.year, manilaDay.month, manilaDay.day).add(Duration(minutes: minutes)).subtract(_offset);

/// Next start/end of a weekly class (1 = Monday) at or after `now`; a class in progress counts until it ends.
({DateTime start, DateTime end}) nextOccurrence(int weekday, String start, String end, DateTime now) {
  final m = manila(now);
  final nowMin = m.hour * 60 + m.minute;
  var add = (weekday - m.weekday + 7) % 7;
  if (add == 0 && nowMin >= toMinutes(end)) add = 7;
  final day = DateTime.utc(m.year, m.month, m.day + add);
  return (start: _instant(day, toMinutes(start)), end: _instant(day, toMinutes(end)));
}

String formatClock(String hhmm) {
  final mins = toMinutes(hhmm);
  final h = mins ~/ 60, m = mins % 60;
  return '${(h + 11) % 12 + 1}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

String relativeStart(DateTime start, DateTime end, DateTime now) {
  if (!now.isBefore(start) && now.isBefore(end)) return 'In progress';
  final diff = start.difference(now).inMinutes;
  if (diff < 60) return 'in $diff min';
  final a = manila(now), b = manila(start);
  bool same(DateTime x, DateTime y) => x.year == y.year && x.month == y.month && x.day == y.day;
  if (same(a, b)) return 'in ${diff ~/ 60} h ${diff % 60} min';
  if (same(manila(now.add(const Duration(days: 1))), b)) return 'Tomorrow';
  return weekdays[b.weekday - 1];
}

/// The app's clock (tests replace it to pin "now").
DateTime Function() appClock = DateTime.now;
