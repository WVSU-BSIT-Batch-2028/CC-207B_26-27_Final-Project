import 'dart:ui';

typedef SchedulePiece = ({String text, Rect bounds});
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _headers = {
  'MONDAY': 1,
  'MON': 1,
  'M': 1,
  'TUESDAY': 2,
  'TUES': 2,
  'TUE': 2,
  'T': 2,
  'WEDNESDAY': 3,
  'WED': 3,
  'W': 3,
  'THURSDAY': 4,
  'THURS': 4,
  'THU': 4,
  'TH': 4,
  'R': 4,
  'FRIDAY': 5,
  'FRI': 5,
  'F': 5,
  'SATURDAY': 6,
  'SAT': 6,
  'S': 6,
  'SUNDAY': 7,
  'SUN': 7,
  'U': 7,
};
final _meetingTime = RegExp(
  r'\d\s*[:.]\s*\d{2}\s*(?:[AP]\s*\.?\s*M\.?)?\s*[-–—−]\s*\d',
  caseSensitive: false,
);

/// Uses explicit aligned weekday headings and printed time ranges in each
/// column. It does not infer missing times from the size of a colored block.
String? readWeeklyGrid(
  List<SchedulePiece> lines, {
  List<SchedulePiece>? words,
}) {
  final candidates = <({int day, SchedulePiece piece})>[];
  for (final piece in words ?? lines) {
    final key = piece.text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final day = _headers[key];
    if (day != null && !piece.bounds.isEmpty) {
      candidates.add((day: day, piece: piece));
    }
  }
  List<({int day, SchedulePiece piece})> best = [];
  for (final candidate in candidates) {
    final band = <int, ({int day, SchedulePiece piece})>{};
    for (final item in candidates) {
      if ((item.piece.bounds.center.dy - candidate.piece.bounds.center.dy)
              .abs() <=
          candidate.piece.bounds.height * .8) {
        band.putIfAbsent(item.day, () => item);
      }
    }
    final items = band.values.toList()
      ..sort(
        (a, b) => a.piece.bounds.center.dx.compareTo(b.piece.bounds.center.dx),
      );
    if (items.length < 2 ||
        (items.length == 2 && items.any((h) => h.piece.text.trim().length < 3))) {
      continue;
    }
    if (items.length > best.length) best = items;
  }
  if (best.length < 2) return null;
  final centers = best.map((h) => h.piece.bounds.center.dx).toList();
  final headerBottom = best
      .map((h) => h.piece.bounds.bottom)
      .reduce((a, b) => a > b ? a : b);
  final result = StringBuffer();
  var meetings = 0;
  for (var i = 0; i < best.length; i++) {
    final left = i == 0
        ? centers[0] - (centers[1] - centers[0]) / 2
        : (centers[i - 1] + centers[i]) / 2;
    final right = i == best.length - 1
        ? centers[i] + (centers[i] - centers[i - 1]) / 2
        : (centers[i] + centers[i + 1]) / 2;
    if (right - left <= 0) return null;
    final column =
        lines
            .where(
              (p) =>
                  p.bounds.top > headerBottom &&
                  p.bounds.center.dx >= left &&
                  p.bounds.center.dx < right &&
                  p.bounds.width < (right - left) * 1.4,
            )
            .toList()
          ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
    for (final piece in column) {
      if (_meetingTime.hasMatch(piece.text)) {
        result.writeln('${piece.text} | ${_dayNames[best[i].day - 1]}');
        meetings++;
      } else {
        result.writeln(piece.text);
      }
    }
    result.writeln();
  }
  return meetings == 0 ? null : result.toString();
}
