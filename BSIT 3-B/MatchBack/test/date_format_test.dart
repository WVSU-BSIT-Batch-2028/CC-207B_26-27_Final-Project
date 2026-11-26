import 'package:flutter_test/flutter_test.dart';
import 'package:matchback/utils/date_format.dart';

// Checks the Philippine-time formatting. No Firebase is needed.
void main() {
  test('converts UTC to Philippine time (UTC+8)', () {
    expect(
      formatPhilippineTime(DateTime.utc(2026, 10, 26, 2, 35)),
      'October 26, 2026, 10:35 AM',
    );
  });

  test('uses PM for afternoon times', () {
    expect(
      formatPhilippineTime(DateTime.utc(2026, 10, 27, 6, 15)),
      'October 27, 2026, 2:15 PM',
    );
  });

  test('rolls over to the next day and shows 12 AM at midnight', () {
    expect(
      formatPhilippineTime(DateTime.utc(2026, 10, 26, 16, 5)),
      'October 27, 2026, 12:05 AM',
    );
  });
}
