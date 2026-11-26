import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/health_record.dart';
import 'package:health360/models/lab_result_detail.dart';
import 'package:health360/services/records_service.dart';

// Tests for how RecordsService turns Firestore documents (plain maps) into
// list cards and popup data. No Firebase needed.
void main() {
  final service = RecordsService.instance;
  final date = DateTime(2026, 10, 5);

  group('consultationRecordFrom', () {
    test('maps department and doctor to title and subtitle', () {
      final r = service.consultationRecordFrom('c1', {
        'department': 'Cardiology',
        'doctorName': 'Dr. Reyes',
        'date': Timestamp.fromDate(date),
      })!;
      expect(r.id, 'c1');
      expect(r.type, RecordType.consultation);
      expect(r.title, 'Cardiology');
      expect(r.subtitle, 'Dr. Reyes');
      expect(r.date, date);
    });

    test('uses defaults when fields are missing', () {
      final r = service.consultationRecordFrom('c2', {'date': date.toIso8601String()})!;
      expect(r.title, 'General Consultation');
      expect(r.subtitle, 'Doctor');
    });

    test('returns null when there is no date', () {
      expect(service.consultationRecordFrom('c3', {'department': 'X'}), isNull);
    });
  });

  group('labRecordFrom', () {
    test('uses a fixed title and the test name as subtitle', () {
      final r = service.labRecordFrom('l1', {'name': 'CBC', 'date': Timestamp.fromDate(date)})!;
      expect(r.type, RecordType.labResult);
      expect(r.title, 'Laboratory Results');
      expect(r.subtitle, 'CBC');
    });

    test('returns null when there is no date', () {
      expect(service.labRecordFrom('l2', {'name': 'CBC'}), isNull);
    });
  });

  group('consultationDetailFrom', () {
    test('reads diagnosis and treatment', () {
      final d = service.consultationDetailFrom('c1', {
        'doctorName': 'Dr. Reyes',
        'department': 'ENT',
        'type': 'Follow-up',
        'date': Timestamp.fromDate(date),
        'diagnosis': 'Sinusitis',
        'treatment': 'Rest',
      });
      expect(d.diagnosis, 'Sinusitis');
      expect(d.treatment, 'Rest');
      expect(d.type, 'Follow-up');
    });

    test('falls back to the plan field "notes" for the diagnosis', () {
      final d = service.consultationDetailFrom('c2', {'date': date.toIso8601String(), 'notes': 'Mild fever'});
      expect(d.diagnosis, 'Mild fever');
      expect(d.treatment, 'No recommendations recorded.');
      expect(d.doctorName, 'Not recorded');
    });

    test('throws RecordsException without a date', () {
      expect(() => service.consultationDetailFrom('c3', {}), throwsA(isA<RecordsException>()));
    });
  });

  group('labDetailFrom', () {
    test('maps values, flags and the patient name passed in', () {
      final d = service.labDetailFrom(
        'l1',
        {
          'name': 'CBC',
          'enteredBy': 'Dr. Reyes',
          'date': Timestamp.fromDate(date),
          'values': [
            {'name': 'Hemoglobin', 'value': 14.2, 'unit': 'g/dL', 'range': '13.0-17.0', 'flag': 'normal'},
            {'name': 'WBC', 'value': 12.5, 'unit': 'x10^9/L', 'range': '4.0-11.0', 'flag': 'high'},
          ],
        },
        'Jahna',
      );
      expect(d.patientName, 'Jahna');
      expect(d.requestedBy, 'Dr. Reyes');
      expect(d.status, 'Complete');
      expect(d.results, hasLength(2));
      expect(d.results[1].flag, LabFlag.high);
      expect(d.hasAbnormal, isTrue);
    });

    test('no values list gives an empty table and default texts', () {
      final d = service.labDetailFrom('l2', {'date': date.toIso8601String()}, 'Patient');
      expect(d.results, isEmpty);
      expect(d.hasAbnormal, isFalse);
      expect(d.overallResult, 'No summary recorded.');
      expect(d.doctorNotes, 'No notes recorded.');
    });

    test('throws RecordsException without a date', () {
      expect(() => service.labDetailFrom('l3', {}, 'P'), throwsA(isA<RecordsException>()));
    });
  });
}
