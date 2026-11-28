import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/child_validators.dart';

// Rules follow the child profile contract in littlesteps-api.
void main() {
  // A fixed "today" so the results never depend on the real date.
  final now = DateTime(2026, 11);

  group('validateNickname', () {
    test('accepts a normal nickname', () {
      expect(validateNickname('Mia'), isNull);
    });

    // Spaces are trimmed, so a spaces-only nickname counts as empty.
    test('rejects an empty or spaces-only nickname', () {
      expect(validateNickname(''), 'Enter a nickname');
      expect(validateNickname('   '), 'Enter a nickname');
      expect(validateNickname(null), 'Enter a nickname');
    });

    // The API allows at most 50 characters.
    test('accepts 50 characters but rejects 51', () {
      expect(validateNickname('a' * 50), isNull);
      expect(validateNickname('a' * 51), 'Use 50 characters or fewer');
    });

    // The API rejects invisible control characters, such as tabs or line breaks.
    test('rejects a nickname with a line break or tab', () {
      expect(
        validateNickname('Mi\na'),
        "Nickname can't contain line breaks or tabs",
      );
      expect(
        validateNickname('Mi\ta'),
        "Nickname can't contain line breaks or tabs",
      );
    });

    // Stricter than the API: letters, spaces, - ' and . only.
    test('rejects numbers and symbols', () {
      expect(
        validateNickname('3443'),
        "Use letters only. Spaces, - and ' are fine.",
      );
      expect(
        validateNickname('Mia2'),
        "Use letters only. Spaces, - and ' are fine.",
      );
    });

    test('accepts hyphens, apostrophes and accents', () {
      expect(validateNickname('Mary-Ann'), isNull);
      expect(validateNickname("O'Neil"), isNull);
      expect(validateNickname('José'), isNull);
    });
  });

  group('validateBirthMonthYear', () {
    test('accepts a birth date within the supported range', () {
      // 2025-03 to 2026-11 is 20 months.
      expect(validateBirthMonthYear(year: 2025, month: 3, now: now), isNull);
    });

    // A child born this month is 0 months old, the youngest allowed.
    test('accepts a child born this month (0 months)', () {
      expect(validateBirthMonthYear(year: 2026, month: 11, now: now), isNull);
    });

    // The API supports ages 0-71 months, so the oldest allowed is 71 months.
    test('accepts exactly 71 months, the oldest allowed', () {
      expect(validateBirthMonthYear(year: 2020, month: 12, now: now), isNull);
    });

    test('rejects a birth date in the future', () {
      expect(
        validateBirthMonthYear(year: 2026, month: 12, now: now),
        "Birth date can't be in the future",
      );
    });

    test('rejects 72 months, one past the oldest allowed', () {
      expect(
        validateBirthMonthYear(year: 2020, month: 11, now: now),
        'Little Steps supports ages 0-71 months',
      );
    });
  });
}
