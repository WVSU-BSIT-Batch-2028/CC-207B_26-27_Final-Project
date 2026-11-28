import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/journal_validators.dart';

// Rules follow the journal schemas in littlesteps-api.
void main() {
  const limitMessage =
      'Notes can be up to 2,000 characters. '
      'Please make this one a little shorter.';

  group('validateJournalContent', () {
    test('accepts a normal note', () {
      expect(validateJournalContent('Mia stacked four cups.'), isNull);
    });

    test('rejects an empty or blank note', () {
      expect(validateJournalContent(null), 'Write a note');
      expect(validateJournalContent(''), 'Write a note');
      expect(validateJournalContent('   '), 'Write a note');
      expect(validateJournalContent('\n\n'), 'Write a note');
    });

    test('accepts 2,000 characters but rejects 2,001', () {
      expect(validateJournalContent('a' * maxJournalLength), isNull);
      expect(
        validateJournalContent('a' * (maxJournalLength + 1)),
        limitMessage,
      );
    });

    // Unlike nicknames, notes may span several lines.
    test('accepts line breaks and tabs', () {
      expect(validateJournalContent('Line one\nLine two'), isNull);
      expect(validateJournalContent('Line one\r\n\tLine two'), isNull);
    });

    test('rejects hidden characters', () {
      expect(
        validateJournalContent('Mia\u0000'),
        'Remove hidden characters from the note',
      );
      expect(
        validateJournalContent('Mia​'),
        'Remove hidden characters from the note',
      );
    });
  });

  group('validateEntryDate', () {
    // A fixed "today" so the results never depend on the real date.
    final now = DateTime(2026, 11, 24, 15, 30);

    test('accepts today, even later in the day', () {
      expect(validateEntryDate(DateTime(2026, 11, 24), now: now), isNull);
      expect(
        validateEntryDate(DateTime(2026, 11, 24, 23, 59), now: now),
        isNull,
      );
    });

    test('accepts a past date', () {
      expect(validateEntryDate(DateTime(2026, 1, 1), now: now), isNull);
    });

    test('rejects tomorrow', () {
      expect(
        validateEntryDate(DateTime(2026, 11, 25), now: now),
        "The date can't be in the future",
      );
    });
  });
}
