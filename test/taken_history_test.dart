import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/taken_history.dart';

void main() {
  group('TakenHistory', () {
    final days = [
      DateTime(2026, 9, 5),
      DateTime(2026, 9, 4),
      DateTime(2026, 9, 3),
      DateTime(2026, 9, 2),
    ];

    test('takenCount is the number of days', () {
      expect(TakenHistory(days).takenCount, 4);
      expect(const TakenHistory([]).takenCount, 0);
    });

    test('recent returns the first days, newest first', () {
      final recent = TakenHistory(days).recent(2);
      expect(recent, [DateTime(2026, 9, 5), DateTime(2026, 9, 4)]);
    });

    test('recent returns everything when there are fewer days than asked', () {
      expect(TakenHistory(days).recent(10).length, 4);
    });
  });
}
