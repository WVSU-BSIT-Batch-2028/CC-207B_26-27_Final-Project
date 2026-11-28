import 'age_band.dart';

/// Maximum nickname length accepted by the API after trimming whitespace.
const int maxNicknameLength = 50;

// Matches invisible ASCII control characters rejected by the API.
final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

// Restricts nicknames to letters (any script), spaces, hyphens, apostrophes,
// and periods (stricter than the backend validator for cleaner display names).
final RegExp _allowedNickname = RegExp(r"^[\p{L}\p{M} '.-]+$", unicode: true);

/// Returns a validation error message if [value] is invalid, or `null` if valid.
///
/// Leading and trailing spaces are trimmed before checking length and content.
String? validateNickname(String? value) {
  final nickname = (value ?? '').trim();

  if (nickname.isEmpty) {
    return 'Enter a nickname';
  }
  if (nickname.length > maxNicknameLength) {
    return 'Use $maxNicknameLength characters or fewer';
  }
  if (_controlCharacters.hasMatch(nickname)) {
    return "Nickname can't contain line breaks or tabs";
  }
  if (!_allowedNickname.hasMatch(nickname)) {
    return "Use letters only. Spaces, - and ' are fine.";
  }
  return null;
}

/// Returns a validation error if [year]/[month] is outside supported [ageBands]
/// on [now], or `null` if valid.
String? validateBirthMonthYear({
  required int year,
  required int month,
  required DateTime now,
}) {
  final months = ageInMonths(birthYear: year, birthMonth: month, now: now);
  final maxMonths = ageBands.last.maxMonths;

  if (months < 0) {
    return "Birth date can't be in the future";
  }
  if (months > maxMonths) {
    return 'Little Steps supports ages 0-$maxMonths months';
  }
  return null;
}
