import 'package:flutter_test/flutter_test.dart';
import 'package:health360/services/drug_info_service.dart';

void main() {
  group('usGenericName', () {
    test('lower-cases and trims the name', () {
      expect(usGenericName('  Amoxicillin '), 'amoxicillin');
    });

    test('swaps names that differ in US labels', () {
      expect(usGenericName('Paracetamol'), 'acetaminophen');
    });
  });

  group('drugInfoFromLabel', () {
    test('shortens long label text to one line', () {
      final info = drugInfoFromLabel('amoxicillin', {
        'indications_and_usage': ['Treats   bacterial\n infections. ' * 40],
        'warnings': ['Tell your doctor about allergies.'],
      });

      expect(info, isNotNull);
      expect(info!.uses!.length, lessThanOrEqualTo(324)); // 320 + "..."
      expect(info.uses!.endsWith('...'), isTrue);
      expect(info.uses!.contains('\n'), isFalse);
      expect(info.warnings, 'Tell your doctor about allergies.');
    });

    test('uses warnings_and_cautions when there are no warnings', () {
      final info = drugInfoFromLabel('x', {
        'warnings_and_cautions': ['Use with care.'],
      });
      expect(info!.warnings, 'Use with care.');
    });

    test('returns null when the label has nothing to show', () {
      expect(drugInfoFromLabel('x', {'other': ['text']}), isNull);
      expect(drugInfoFromLabel('x', {'warnings': []}), isNull);
    });
  });
}