import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/utils/date_formatting.dart';
import 'package:littlesteps/utils/domain_labels.dart';

void main() {
  group('Shared utility helpers', () {
    test(
      'formatIsoDate formats dates with zero-padded year, month, and day',
      () {
        expect(formatIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
        expect(formatIsoDate(DateTime(2026, 11, 27)), '2026-11-27');
        expect(todayIsoDate(), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      },
    );

    test('friendlyDomainLabel maps backend domain keys consistently', () {
      expect(friendlyDomainLabel('cognitive'), 'Thinking');
      expect(friendlyDomainLabel('motor'), 'Moving');
      expect(friendlyDomainLabel('language'), 'Talking');
      expect(friendlyDomainLabel('socioEmotional'), 'Feelings');
      expect(friendlyDomainLabel('socio_emotional'), 'Feelings');
      expect(friendlyDomainLabel('unknown'), 'Talking');
    });

    test('formalDomainLabel maps backend domain keys consistently', () {
      expect(formalDomainLabel('cognitive'), 'Cognitive');
      expect(formalDomainLabel('motor'), 'Motor');
      expect(formalDomainLabel('language'), 'Language');
      expect(formalDomainLabel('socioEmotional'), 'Socio-emotional');
      expect(formalDomainLabel('custom'), 'Custom');
    });

    test('formatSettingLabel maps play settings consistently', () {
      expect(formatSettingLabel('indoor'), 'Indoor');
      expect(formatSettingLabel('outdoor'), 'Outdoor');
      expect(formatSettingLabel('either'), 'Indoor or outdoor');
      expect(formatSettingLabel('other'), 'other');
    });
  });
}
