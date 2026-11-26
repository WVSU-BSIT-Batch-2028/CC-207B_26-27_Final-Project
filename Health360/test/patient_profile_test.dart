import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/patient_profile.dart';
import 'package:health360/models/patient_record.dart';

// Tests for the Edit Patient Info helpers. No Firebase needed.
void main() {
  group('splitList', () {
    test('splits on commas and drops empty parts', () {
      expect(splitList('Penicillin, Peanuts,, '), ['Penicillin', 'Peanuts']);
      expect(splitList(''), isEmpty);
    });
  });

  group('parseHistory', () {
    test('reads "Condition (year)" lines', () {
      final list = parseHistory('Hypertension (2019)\nAsthma (2010)');
      expect(list, hasLength(2));
      expect(list.first.condition, 'Hypertension');
      expect(list.first.diagnosedYear, 2019);
    });

    test('a line without a year gets year 0; blank lines are skipped', () {
      final list = parseHistory('Diabetes\n\n  ');
      expect(list, hasLength(1));
      expect(list.first.condition, 'Diabetes');
      expect(list.first.diagnosedYear, 0);
    });

    test('historyText is the reverse of parseHistory', () {
      const history = [
        MedicalHistoryEntry(condition: 'Hypertension', diagnosedYear: 2019),
        MedicalHistoryEntry(condition: 'Asthma', diagnosedYear: 0),
      ];
      final text = historyText(history);
      expect(text, 'Hypertension (2019)\nAsthma');
      expect(parseHistory(text).first.diagnosedYear, 2019);
    });
  });

  group('PatientProfile', () {
    test('no document gives an empty, active profile', () {
      final p = PatientProfile.fromMap(null);
      expect(p.age, isNull);
      expect(p.isActive, isTrue);
      expect(p.allergies, isEmpty);
    });

    test('toMap and fromMap keep every field', () {
      const original = PatientProfile(
        age: 34,
        sex: 'Female',
        phone: '09171234567',
        condition: 'Asthma',
        isActive: false,
        allergies: ['Penicillin'],
        immunizations: ['Influenza (2024)'],
        history: [MedicalHistoryEntry(condition: 'Asthma', diagnosedYear: 2010)],
      );
      final copy = PatientProfile.fromMap(original.toMap());
      expect(copy.age, 34);
      expect(copy.sex, 'Female');
      expect(copy.phone, '09171234567');
      expect(copy.condition, 'Asthma');
      expect(copy.isActive, isFalse);
      expect(copy.allergies, ['Penicillin']);
      expect(copy.immunizations, ['Influenza (2024)']);
      expect(copy.history.single.diagnosedYear, 2010);
    });
  });
}
