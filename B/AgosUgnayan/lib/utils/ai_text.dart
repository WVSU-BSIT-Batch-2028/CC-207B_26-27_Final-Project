// Cleans the AI's crop description before it goes into the form: plain
// text only (no markdown, no quotes around it), one paragraph, and at most
// 300 characters, cut at the end of a sentence so it never stops mid-word.
// Kept apart from AiService so it is easy to unit-test.

/// Longest description we put in the form (the field allows 500).
const int kAiDescriptionMax = 300;

/// The cleaned description, or null when nothing useful is left.
String? cleanCropDescription(String? raw, {int max = kAiDescriptionMax}) {
  if (raw == null) return null;
  var text = raw
      .replaceAll(RegExp(r'```[a-z]*'), '') // code fences
      .replaceAll(RegExp(r'[*_#>`]'), '') // markdown marks
      .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '') // bullets
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Remove quotes around the whole text, e.g. "Fresh lettuce ...".
  if (text.length > 1 &&
      (text.startsWith('"') || text.startsWith('“')) &&
      (text.endsWith('"') || text.endsWith('”'))) {
    text = text.substring(1, text.length - 1).trim();
  }
  if (text.length < 10) return null; // too short to be a description
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final end = cut.lastIndexOf('. ');
  if (end > max ~/ 3) return cut.substring(0, end + 1);
  return '${cut.substring(0, cut.lastIndexOf(' ')).trimRight()}…';
}
