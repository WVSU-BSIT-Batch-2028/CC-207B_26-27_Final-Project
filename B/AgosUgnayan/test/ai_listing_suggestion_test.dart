// Unit tests for AiListingSuggestion: good AI answers are kept, bad values
// are dropped one field at a time, and non-JSON answers are rejected.

import 'package:agosugnayan/models/ai_listing_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a valid answer', () {
    final s = AiListingSuggestion.fromJsonText(
      '{"crop": "Tomato", "quantity": 50, "unit": "kg", "price": 45, '
      '"description": "Fresh tomatoes."}',
    );
    expect(s.crop, 'Tomato');
    expect(s.quantity, 50);
    expect(s.unit, 'kg');
    expect(s.price, 45);
    expect(s.description, 'Fresh tomatoes.');
  });

  test('reads an answer sent as a list with one object (Lite model)', () {
    final s = AiListingSuggestion.fromJsonText(
      '[{"crop":"pechay","quantity":20,"unit":"kg","price":54.4}]',
    );
    expect(s.crop, 'Pechay');
    expect(s.quantity, 20);
    expect(s.price, 54.4);
  });

  test('turns a local crop name into our crop name', () {
    final s = AiListingSuggestion.fromJsonText('{"crop": "kamatis"}');
    expect(s.crop, 'Tomato');
  });

  test('drops values we cannot use', () {
    final s = AiListingSuggestion.fromJsonText(
      '{"crop": "Strawberry", "quantity": -5, "unit": "ton", "price": null}',
    );
    expect(s.crop, isNull);
    expect(s.quantity, isNull);
    expect(s.unit, isNull);
    expect(s.price, isNull);
    expect(s.isEmpty, isTrue);
  });

  test('reads JSON wrapped in a code block', () {
    final s = AiListingSuggestion.fromJsonText(
      '```json\n{"crop": "Okra"}\n```',
    );
    expect(s.crop, 'Okra');
  });

  test('rejects an answer that is not JSON', () {
    expect(
      () => AiListingSuggestion.fromJsonText('Sorry, I cannot help.'),
      throwsFormatException,
    );
  });
}
