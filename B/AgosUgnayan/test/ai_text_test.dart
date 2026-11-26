// Unit tests for cleaning the AI's crop description (lib/utils/ai_text.dart).

import 'package:agosugnayan/utils/ai_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a normal description as it is', () {
    const text = 'Lettuce is a leafy vegetable with soft green leaves.';
    expect(cleanCropDescription(text), text);
  });

  test('removes markdown, bullets, quotes and extra spaces', () {
    const raw = '"**Lettuce** is a  leafy vegetable.\n- Eat it fresh."';
    expect(
      cleanCropDescription(raw),
      'Lettuce is a leafy vegetable. Eat it fresh.',
    );
  });

  test('cuts long text at the end of a sentence, within the limit', () {
    final raw = 'Mango is a sweet tropical fruit. ' * 20;
    final clean = cleanCropDescription(raw)!;
    expect(clean.length, lessThanOrEqualTo(kAiDescriptionMax));
    expect(clean.endsWith('.'), isTrue);
  });

  test('empty or too short answers give null', () {
    expect(cleanCropDescription(null), isNull);
    expect(cleanCropDescription('   '), isNull);
    expect(cleanCropDescription('Mango.'), isNull);
  });
}
