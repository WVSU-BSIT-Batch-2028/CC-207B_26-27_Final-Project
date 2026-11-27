import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:wvsu_wayfinder/data/schedule_layout.dart';
import 'package:wvsu_wayfinder/data/schedule_import.dart';

SchedulePiece piece(String text, double x, double y, {double width = 80}) =>
    (text: text, bounds: Rect.fromLTWH(x, y, width, 10));

void main() {
  test(
    'weekday grid headings assign printed meetings to the correct columns',
    () {
      final lines = [
        piece('Monday', 80, 10),
        piece('Wednesday', 220, 10),
        piece('Friday', 360, 10),
        piece('CC 207 Web Systems', 70, 50, width: 100),
        piece('08:00-09:00', 70, 65),
        piece('CB203', 70, 80),
        piece('CIT 210 Databases', 210, 50, width: 100),
        piece('13:00-14:30', 210, 65),
        piece('CB204', 210, 80),
        piece('GE 1 Ethics', 350, 50, width: 100),
        piece('10:00-11:00', 350, 65),
        piece('CB205', 350, 80),
      ];
      final text = readWeeklyGrid(lines)!;
      final meetings = parseScheduleText(text).sessions;
      expect(meetings.map((c) => c.weekday), [1, 3, 5]);
      expect(meetings.map((c) => c.roomCodeRaw), ['CB203', 'CB204', 'CB205']);
    },
  );
  test('room codes and student initials do not invent weekday headers', () {
    expect(
      readWeeklyGrid([
        piece('CB203', 80, 10),
        piece('CB204', 220, 10),
        piece('CC 207 08:00-09:00', 80, 50),
      ]),
      isNull,
    );
    expect(
      readWeeklyGrid([
        piece('M', 80, 10),
        piece('T', 220, 10),
        piece('08:00-09:00', 80, 50),
      ]),
      isNull,
    );
  });
  test(
    'colored blocks without printed meeting times need review, not guessed times',
    () {
      expect(
        readWeeklyGrid([
          piece('Monday', 80, 10),
          piece('Wednesday', 220, 10),
          piece('CC 207', 80, 50),
          piece('CIT 210', 220, 50),
        ]),
        isNull,
      );
    },
  );
}
