import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/doctor_prescription.dart';
import 'package:health360/models/refill_request.dart';
import 'package:health360/services/prescription_mapper.dart';

/// A realistic prescription document as Firestore would return it.
Map<String, dynamic> _doc({Map<String, dynamic>? overrides}) => {
      'patientId': 'PAT-101',
      'doctorId': 'doc-uid',
      'doctorName': 'Dr. Maria Santos',
      'medicineName': 'Amoxicillin',
      'dosage': '500mg',
      'form': 'capsule',
      'timesPerDay': 2,
      'durationDays': 7,
      'startDate': Timestamp.fromDate(DateTime(2026, 9, 12)),
      'refillDate': Timestamp.fromDate(DateTime(2026, 9, 19)),
      'notes': 'Take after meals.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 12, 14, 30)),
      ...?overrides,
    };

void main() {
  group('prescriptionFromData', () {
    test('maps the stored fields to the patient-side model', () {
      final p = prescriptionFromData('rx-1', _doc());

      expect(p.id, 'rx-1');
      expect(p.title, 'Amoxicillin 500mg');
      expect(p.form, 'Capsule'); // capitalised for display
      expect(p.instruction, 'Take 1 capsule - 2x a day');
      expect(p.durationDays, 7);
      expect(p.startDate, DateTime(2026, 9, 12));
      expect(p.refillDate, DateTime(2026, 9, 19));
      expect(p.prescribedBy, 'Dr. Maria Santos');
      expect(p.prescribedOn, DateTime(2026, 9, 12));
      expect(p.notes, 'Take after meals.');
      expect(p.doctorPhone, '');
    });

    test('falls back to safe defaults for optional fields', () {
      final p = prescriptionFromData(
        'rx-2',
        _doc(overrides: {
          'doctorName': null,
          'refillDate': null,
          'notes': null,
          'createdAt': null,
        }),
      );

      expect(p.prescribedBy, 'Your doctor');
      expect(p.refillDate, isNull);
      expect(p.notes, isNull);
      expect(p.prescribedOn, DateTime(2026, 9, 12)); // falls back to start date
    });

    test('rejects a document missing required fields', () {
      expect(
        () => prescriptionFromData('rx-3', _doc(overrides: {'startDate': null})),
        throwsFormatException,
      );
      expect(
        () => prescriptionFromData('rx-4', _doc(overrides: {'medicineName': null})),
        throwsFormatException,
      );
    });
  });

  group('doctorPrescriptionFromData / doctorPrescriptionToData', () {
    test('reads the doctor-side model from the same document', () {
      final p = doctorPrescriptionFromData('rx-1', _doc());

      expect(p.medicineName, 'Amoxicillin');
      expect(p.dosage, '500mg');
      expect(p.form, 'capsule'); // stays lower-case for the doctor's list
      expect(p.timesPerDay, 2);
      expect(p.instructionText, 'Take 1 capsule - 2x a day');
    });

    test('writes the fields the patient side reads back', () {
      final data = doctorPrescriptionToData(
        DoctorPrescription(
          id: 'rx-9',
          medicineName: 'Cetirizine',
          dosage: '10mg',
          form: 'tablet',
          timesPerDay: 1,
          durationDays: 30,
          startDate: DateTime(2026, 9, 10, 15, 45), // time is dropped
        ),
        patientId: 'PAT-101',
        doctorId: 'doc-uid',
        doctorName: 'Dr. Maria Santos',
      );

      expect(data['patientId'], 'PAT-101');
      expect(data['doctorId'], 'doc-uid');
      expect(data['medicineName'], 'Cetirizine');
      expect(data['refillDate'], isNull);
      expect((data['startDate'] as Timestamp).toDate(), DateTime(2026, 9, 10));

      // Round trip: what the doctor wrote is what the patient reads.
      final back = prescriptionFromData('rx-9', data);
      expect(back.title, 'Cetirizine 10mg');
      expect(back.instruction, 'Take 1 tablet - 1x a day');
    });
  });

  group('refillRequestFromData', () {
    test('reads each status', () {
      for (final status in RefillStatus.values) {
        final r = refillRequestFromData({
          'prescriptionId': 'rx-1',
          'status': status.name,
          'requestedAt': Timestamp.fromDate(DateTime(2026, 9, 13)),
        });
        expect(r.status, status);
        expect(r.prescriptionId, 'rx-1');
      }
    });

    test('treats an unknown or missing status as pending', () {
      expect(
        refillRequestFromData({'prescriptionId': 'rx-1', 'status': 'weird'})
            .status,
        RefillStatus.pending,
      );
      expect(
        refillRequestFromData({'prescriptionId': 'rx-1'}).status,
        RefillStatus.pending,
      );
    });
  });

  group('refillNoticeFromData', () {
    test('reads who asked and for what', () {
      final n = refillNoticeFromData('PAT-101_rx-1', {
        'prescriptionId': 'rx-1',
        'patientName': 'Ana Dela Cruz',
        'medicineTitle': 'Amoxicillin 500mg',
        'patientUid': 'uid-1',
        'requestedAt': Timestamp.fromDate(DateTime(2026, 9, 13, 9, 30)),
      });

      expect(n.id, 'PAT-101_rx-1');
      expect(n.prescriptionId, 'rx-1');
      expect(n.patientName, 'Ana Dela Cruz');
      expect(n.medicineTitle, 'Amoxicillin 500mg');
      expect(n.patientUid, 'uid-1');
      expect(n.requestedAt, DateTime(2026, 9, 13, 9, 30));
    });

    test('falls back for requests saved before the name was stored', () {
      final n = refillNoticeFromData('PAT-101_rx-1', {'prescriptionId': 'rx-1'});

      expect(n.patientName, 'A patient');
      expect(n.medicineTitle, 'a medicine');
      expect(n.patientUid, isNull);
    });
  });
}