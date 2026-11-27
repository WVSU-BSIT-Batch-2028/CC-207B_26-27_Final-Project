import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/vital_sign.dart';
import 'package:health360/services/patients_service.dart';

// Tests for how PatientsService turns Firestore documents (plain maps) into
// app models. They need no Firebase: the helpers only read the maps.
void main() {
  final service = PatientsService.instance;

  group('toPatient', () {
    test('builds a patient from account + profile + last visit', () {
      final visit = DateTime(2026, 11, 1);
      final p = service.toPatient(
        'u1',
        {'fullName': 'Jahna Lagne'},
        {'condition': 'Asthma', 'isActive': true, 'age': 21, 'sex': 'Female', 'phone': '0912'},
        visit,
      );
      expect(p.id, 'u1');
      expect(p.name, 'Jahna Lagne');
      expect(p.condition, 'Asthma');
      expect(p.isActive, isTrue);
      expect(p.age, 21);
      expect(p.sex, 'Female');
      expect(p.phone, '0912');
      expect(p.lastVisit, visit);
    });

    test('a patient with no profile uses safe defaults and counts as active', () {
      final p = service.toPatient('u2', {}, null, null);
      expect(p.name, 'Unnamed patient');
      expect(p.condition, 'No condition recorded');
      expect(p.isActive, isTrue);
      expect(p.age, isNull);
      expect(p.sex, isNull);
      expect(p.phone, isNull);
      expect(p.lastVisit, isNull);
    });

    test('isActive false puts the patient in History', () {
      final p = service.toPatient('u3', {'fullName': 'A'}, {'isActive': false}, null);
      expect(p.isActive, isFalse);
    });

    test('empty sex and phone become null', () {
      final p = service.toPatient('u4', {'fullName': 'A'}, {'sex': '  ', 'phone': ''}, null);
      expect(p.sex, isNull);
      expect(p.phone, isNull);
    });
  });

  group('historyOf', () {
    test('reads condition and year, skips entries without a condition', () {
      final list = service.historyOf({
        'medicalHistory': [
          {'condition': 'Hypertension', 'diagnosedYear': 2019},
          {'condition': '', 'diagnosedYear': 2020},
          {'diagnosedYear': 2021},
        ],
      });
      expect(list, hasLength(1));
      expect(list.first.condition, 'Hypertension');
      expect(list.first.diagnosedYear, 2019);
    });

    test('missing year becomes 0; missing list or profile gives empty', () {
      expect(service.historyOf({'medicalHistory': [{'condition': 'Flu'}]}).first.diagnosedYear, 0);
      expect(service.historyOf({}), isEmpty);
      expect(service.historyOf(null), isEmpty);
    });
  });

  group('vitalTypeFrom', () {
    test('accepts different spellings of the same type', () {
      expect(service.vitalTypeFrom('bloodPressure'), VitalType.bloodPressure);
      expect(service.vitalTypeFrom('blood_pressure'), VitalType.bloodPressure);
      expect(service.vitalTypeFrom('Blood Pressure'), VitalType.bloodPressure);
      expect(service.vitalTypeFrom('Heart Rate'), VitalType.heartRate);
      expect(service.vitalTypeFrom('weight'), VitalType.weight);
      expect(service.vitalTypeFrom('SLEEP'), VitalType.sleep);
    });

    test('unknown or null gives null', () {
      expect(service.vitalTypeFrom('glucose'), isNull);
      expect(service.vitalTypeFrom(null), isNull);
    });
  });

  group('timesFromText', () {
    test('numbers, "twice" and unclear text', () {
      expect(service.timesFromText('3x a day'), 3);
      expect(service.timesFromText('2 times daily'), 2);
      expect(service.timesFromText('Twice a day'), 2);
      expect(service.timesFromText('Once a day'), 1);
      expect(service.timesFromText(null), 1);
      expect(service.timesFromText('as needed'), 1);
    });
  });

  group('toPrescription', () {
    final start = DateTime(2026, 11, 1);

    test('returns null without a start date', () {
      expect(service.toPrescription('p1', {'medicine': 'X'}), isNull);
    });

    test('reads the plan fields and works out times and duration', () {
      final rx = service.toPrescription('p1', {
        'medicine': 'Amoxicillin',
        'dosage': '500mg',
        'frequency': 'Twice a day',
        'startDate': Timestamp.fromDate(start),
        'endDate': Timestamp.fromDate(start.add(const Duration(days: 7))),
        'notes': 'After meals',
      })!;
      expect(rx.id, 'p1');
      expect(rx.medicineName, 'Amoxicillin');
      expect(rx.dosage, '500mg');
      expect(rx.timesPerDay, 2);
      expect(rx.durationDays, 7);
      expect(rx.form, 'dose');
      expect(rx.notes, 'After meals');
    });

    test('extra fields win over the plan fields', () {
      final rx = service.toPrescription('p2', {
        'medicine': 'Cetirizine',
        'frequency': 'Once a day',
        'timesPerDay': 3,
        'durationDays': 10,
        'form': 'tablet',
        'startDate': start.toIso8601String(),
      })!;
      expect(rx.timesPerDay, 3);
      expect(rx.durationDays, 10);
      expect(rx.form, 'tablet');
      expect(rx.notes, isNull);
    });

    test('no end date and no duration defaults to 1 day', () {
      final rx = service.toPrescription('p3', {'medicine': 'X', 'startDate': start.toIso8601String()})!;
      expect(rx.durationDays, 1);
    });
  });
}
