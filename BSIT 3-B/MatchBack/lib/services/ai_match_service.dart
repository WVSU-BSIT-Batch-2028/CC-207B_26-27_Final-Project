import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/ai_match_suggestion.dart';
import '../models/found_item.dart';
import '../models/lost_item.dart';

/// Asks the AI model which found items might match a lost-item report.
class AiMatchService {
  final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    // Current Firebase-recommended Flash model for this text-matching task.
    model: 'gemini-3.8-flash',
  );

  /// Returns up to three suggestions. An empty list means "no plausible
  /// match". Throws if the AI is unavailable, times out, or replies in a
  /// format we cannot read, so the screen can show its fallback.
  Future<List<AiMatchSuggestion>> suggestMatches({
    required LostItem lostItem,
    required List<FoundItem> foundItems,
  }) async {
    // Only public details are sent. Private details are never included.
    final candidates = foundItems
        .map(
          (item) =>
              '''
Candidate ID: ${item.id}
Item name: ${item.name}
Category: ${item.category}
Public description: ${item.description}
Location found: ${item.locationFound}
Date found: ${item.dateFound}
''',
        )
        .join('\n---\n');

    final prompt =
        '''
You are assisting a campus lost-and-found office.

Compare the lost-item report with the candidate found-item reports.
Suggest only plausible matches based on public descriptions, category,
location, and dates. Descriptions may mix English, Tagalog, or Cebuano.

Lost-item report:
Item name: ${lostItem.name}
Category: ${lostItem.category}
Description: ${lostItem.description}
Last known location: ${lostItem.location}
Date lost: ${lostItem.dateLost}

Candidate found-item reports:
$candidates

Rules:
- Do not decide ownership.
- Do not claim that a match is certain.
- Do not ask for or invent personal data.
- Return at most three possible matches.
- "candidateId" must be exactly one of the Candidate IDs listed above.

Respond with ONLY a JSON array, with no markdown and no extra text:
[{"candidateId": "<id>", "reason": "<short explanation>"}]

If no candidate is plausible, respond with exactly: []
''';

    final response = await _model
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 25));

    final text = response.text?.trim();

    if (text == null || text.isEmpty) {
      throw const FormatException('The AI returned an empty response.');
    }

    return _parse(text, foundItems.map((item) => item.id).toSet());
  }

  /// Turns the AI's JSON text into suggestions, keeping only real IDs.
  List<AiMatchSuggestion> _parse(String text, Set<String> validIds) {
    // The model sometimes wraps JSON in extra text, so find the array.
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end <= start) {
      throw const FormatException('No JSON list found in the AI response.');
    }

    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is! List) {
      throw const FormatException('The AI response was not a list.');
    }

    final seen = <String>{};
    final suggestions = <AiMatchSuggestion>[];

    for (final entry in decoded) {
      if (entry is! Map) continue;

      final id = '${entry['candidateId']}'.trim();
      final reason = '${entry['reason'] ?? ''}'.trim();

      // Skip made-up IDs and duplicates.
      if (!validIds.contains(id) || !seen.add(id)) continue;

      suggestions.add(
        AiMatchSuggestion(
          candidateId: id,
          reason: reason.isEmpty ? 'No reason was given.' : reason,
        ),
      );

      if (suggestions.length == 3) break;
    }

    return suggestions;
  }
}
