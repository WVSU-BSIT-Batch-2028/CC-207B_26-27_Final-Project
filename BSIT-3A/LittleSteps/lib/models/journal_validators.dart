/// Maximum journal note length accepted by the API.
const int maxJournalLength = 2000;

// Matches invisible control characters (except line breaks and tabs) and
// invisible Unicode format characters such as zero-width spaces.
final RegExp _forbiddenCharacters = RegExp(
  r'[^\P{Cc}\r\n\t]|\p{Cf}',
  unicode: true,
);

/// Returns a validation error if [value] is not a valid note, or `null` if valid.
///
/// Line breaks are permitted. Length is checked against the raw typed text to
/// match the backend limit and form character counter.
String? validateJournalContent(String? value) {
  final content = value ?? '';

  if (content.trim().isEmpty) {
    return 'Write a note';
  }
  if (content.length > maxJournalLength) {
    return 'Notes can be up to 2,000 characters. '
        'Please make this one a little shorter.';
  }
  if (_forbiddenCharacters.hasMatch(content)) {
    return 'Remove hidden characters from the note';
  }
  return null;
}

/// Returns a validation error if [date] is after the calendar day of [now],
/// or `null` if valid.
String? validateEntryDate(DateTime date, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);

  if (day.isAfter(today)) {
    return "The date can't be in the future";
  }
  return null;
}
