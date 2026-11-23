import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient.dart';
import '../models/patient_detail.dart';
import '../models/patient_lab_result.dart';
import '../models/patient_record.dart';
import '../models/doctor_prescription.dart';
import '../models/vital_sign.dart';
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import 'appointment_service.dart';
import 'dashboard_service.dart';

/// Thrown when the patients could not be loaded.
class PatientsException implements Exception {
  const PatientsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Loads patients who have booked the currently signed-in doctor.
class PatientsService {
  PatientsService._();

  static final PatientsService instance = PatientsService._();

  /// Returns unique patients from the signed-in doctor's appointments.
  ///
  /// A patient is Active if at least one appointment is pending or confirmed.
  /// Otherwise, the patient appears under History.
  Future<List<Patient>> fetchPatients() async {
    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const PatientsException(
          "We couldn't load your patients. Check your connection and try again.",
        );

      case DemoScenario.empty:
        return const <Patient>[];

      case DemoScenario.normal:
        try {
          final appointments =
              await AppointmentService.instance.fetchAppointments();

          // Group all appointments by the patient's Firebase UID.
          final Map<String, List<Appointment>> grouped = {};

          for (final appointment in appointments) {
            final patientId = appointment.patientId?.trim() ?? '';

            // Ignore incomplete appointment records.
            if (patientId.isEmpty) continue;

            grouped.putIfAbsent(patientId, () => []).add(appointment);
          }

          final patients = <Patient>[];

          for (final entry in grouped.entries) {
            final patientAppointments = entry.value;

            // Most recent appointment first.
            patientAppointments.sort(
              (a, b) => b.dateTime.compareTo(a.dateTime),
            );

            final latestAppointment = patientAppointments.first;

            // A patient remains Active if they have any active appointment.
            final hasActiveAppointment = patientAppointments.any(
              (appointment) =>
                  appointment.status == AppointmentStatus.pending ||
                  appointment.status == AppointmentStatus.confirmed,
            );

            patients.add(
              Patient(
                id: entry.key,
                name: latestAppointment.patientName?.trim().isNotEmpty == true
                    ? latestAppointment.patientName!.trim()
                    : 'Patient',
                age: null,
                sex: null,
                phone: null,
                condition: null,
                lastVisit: latestAppointment.dateTime,
                isActive: hasActiveAppointment,
              ),
            );
          }

          // Most recent appointment first.
          patients.sort(
            (a, b) => b.lastVisit.compareTo(a.lastVisit),
          );

          return List.unmodifiable(patients);
        } on AppointmentException catch (e) {
          throw PatientsException(e.message);
        } catch (_) {
          throw const PatientsException(
            "We couldn't load your patients. Check your connection and try again.",
          );
        }
    }
  }

  /// Returns the medical conditions and allergies of one patient.
  ///
  /// Existing prototype data is retained temporarily.
  Future<PatientDetail> fetchPatientDetail(String patientId) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't load this patient. Check your connection and try again.",
      );
    }

    const details = <String, PatientDetail>{
      'PAT-101': PatientDetail(
        patientId: 'PAT-101',
        conditions: ['Common Cold'],
        allergies: [],
      ),
      'PAT-102': PatientDetail(
        patientId: 'PAT-102',
        conditions: ['Hypertension'],
        allergies: ['Penicillin'],
      ),
      'PAT-103': PatientDetail(
        patientId: 'PAT-103',
        conditions: ['Diarrhea'],
        allergies: [],
      ),
      'PAT-104': PatientDetail(
        patientId: 'PAT-104',
        conditions: ['Asthma'],
        allergies: ['Dust', 'Pollen'],
      ),
    };

    final detail = details[patientId];

    if (detail == null) {
      throw const PatientsException(
        'No medical details are available for this patient yet.',
      );
    }

    return detail;
  }

  /// Returns the medical history, allergies, immunizations and latest vitals.
  Future<PatientRecord> fetchPatientRecord(String patientId) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't load this record. Check your connection and try again.",
      );
    }

    final records = <String, PatientRecord>{
      'PAT-101': PatientRecord(
        patientId: 'PAT-101',
        history: const [
          MedicalHistoryEntry(condition: 'Hypertension', diagnosedYear: 2020),
          MedicalHistoryEntry(condition: 'Common Cold', diagnosedYear: 2026),
        ],
        allergies: const [],
        immunizations: const [],
        vitals: _vitals(
          DateTime(2026, 9, 12),
          systolic: 120,
          diastolic: 60,
          heartRate: 72,
          weightKg: 68,
        ),
      ),
      'PAT-102': PatientRecord(
        patientId: 'PAT-102',
        history: const [
          MedicalHistoryEntry(condition: 'Hypertension', diagnosedYear: 2019),
        ],
        allergies: const ['Penicillin'],
        immunizations: const ['Influenza (2024)'],
        vitals: _vitals(
          DateTime(2025, 5, 15),
          systolic: 148,
          diastolic: 92,
          heartRate: 80,
          weightKg: 82,
        ),
      ),
      'PAT-103': PatientRecord(
        patientId: 'PAT-103',
        history: const [
          MedicalHistoryEntry(condition: 'Diarrhea', diagnosedYear: 2026),
        ],
        allergies: const [],
        immunizations: const [],
        vitals: _vitals(
          DateTime(2026, 9, 10),
          systolic: 110,
          diastolic: 70,
          heartRate: 78,
          weightKg: 55,
        ),
      ),
      'PAT-104': PatientRecord(
        patientId: 'PAT-104',
        history: const [
          MedicalHistoryEntry(condition: 'Asthma', diagnosedYear: 2018),
        ],
        allergies: const ['Dust', 'Pollen'],
        immunizations: const ['Influenza (2023)'],
        vitals: _vitals(
          DateTime(2025, 3, 3),
          systolic: 118,
          diastolic: 76,
          heartRate: 74,
          weightKg: 70,
        ),
      ),
    };

    final record = records[patientId];

    if (record == null) {
      throw const PatientsException(
        'No medical records are available for this patient yet.',
      );
    }

    return record;
  }

  List<VitalSign> _vitals(
    DateTime date, {
    required double systolic,
    required double diastolic,
    required double heartRate,
    required double weightKg,
  }) {
    return [
      VitalSign(
        type: VitalType.bloodPressure,
        label: 'Blood Pressure',
        unit: 'mmHg',
        readings: [
          VitalReading(
            date: date,
            value: systolic,
            secondary: diastolic,
          ),
        ],
      ),
      VitalSign(
        type: VitalType.heartRate,
        label: 'Heart Rate',
        unit: 'bpm',
        readings: [
          VitalReading(date: date, value: heartRate),
        ],
      ),
      VitalSign(
        type: VitalType.weight,
        label: 'Weight',
        unit: 'kg',
        readings: [
          VitalReading(date: date, value: weightKg),
        ],
      ),
    ];
  }

  static const String _addedPrescriptionsPrefix = 'added_prescriptions_';

  Future<List<PatientLabResult>> fetchPatientLabResults(
    String patientId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't load these lab results. Check your connection and try again.",
      );
    }

    final results = <String, List<PatientLabResult>>{
      'PAT-101': [
        PatientLabResult(
          id: 'lab-001',
          testName: 'Complete Blood Count',
          date: DateTime(2026, 9, 8),
        ),
        PatientLabResult(
          id: 'lab-002',
          testName: 'Lipid Profile',
          date: DateTime(2026, 8, 28),
        ),
        PatientLabResult(
          id: 'lab-003',
          testName: 'Urinalysis',
          date: DateTime(2026, 8, 12),
        ),
      ],
      'PAT-102': [
        PatientLabResult(
          id: 'lab-201',
          testName: 'Lipid Profile',
          date: DateTime(2025, 5, 15),
        ),
      ],
      'PAT-103': <PatientLabResult>[],
      'PAT-104': [
        PatientLabResult(
          id: 'lab-401',
          testName: 'Complete Blood Count',
          date: DateTime(2025, 3, 3),
        ),
      ],
    };

    final list = results[patientId];

    if (list == null) {
      throw const PatientsException(
        'No lab results are available for this patient yet.',
      );
    }

    return [...list]..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<DoctorPrescription>> fetchPatientPrescriptions(
    String patientId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't load these prescriptions. Check your connection and try again.",
      );
    }

    final samples = <String, List<DoctorPrescription>>{
      'PAT-101': [
        DoctorPrescription(
          id: 'rx-101-1',
          medicineName: 'Amoxicillin',
          dosage: '500mg',
          form: 'capsule',
          timesPerDay: 2,
          durationDays: 7,
          startDate: DateTime(2026, 9, 12),
          refillDate: DateTime(2026, 10, 1),
          notes: 'Take after meals.',
        ),
        DoctorPrescription(
          id: 'rx-101-2',
          medicineName: 'Paracetamol',
          dosage: '500mg',
          form: 'capsule',
          timesPerDay: 4,
          durationDays: 5,
          startDate: DateTime(2026, 9, 11),
          refillDate: DateTime(2026, 10, 12),
        ),
        DoctorPrescription(
          id: 'rx-101-3',
          medicineName: 'Cetirizine',
          dosage: '10mg',
          form: 'tablet',
          timesPerDay: 1,
          durationDays: 30,
          startDate: DateTime(2026, 9, 10),
          refillDate: DateTime(2027, 1, 20),
          notes: 'May cause drowsiness. Take at night.',
        ),
      ],
      'PAT-102': [
        DoctorPrescription(
          id: 'rx-102-1',
          medicineName: 'Amlodipine',
          dosage: '5mg',
          form: 'tablet',
          timesPerDay: 1,
          durationDays: 30,
          startDate: DateTime(2025, 5, 15),
          refillDate: DateTime(2025, 6, 14),
        ),
        DoctorPrescription(
          id: 'rx-102-2',
          medicineName: 'Paracetamol',
          dosage: '500mg',
          form: 'tablet',
          timesPerDay: 3,
          durationDays: 3,
          startDate: DateTime(2025, 2, 10),
        ),
      ],
      'PAT-103': [
        DoctorPrescription(
          id: 'rx-103-1',
          medicineName: 'Loperamide',
          dosage: '2mg',
          form: 'capsule',
          timesPerDay: 3,
          durationDays: 3,
          startDate: DateTime(2026, 9, 10),
        ),
      ],
      'PAT-104': <DoctorPrescription>[],
    };

    final sample = samples[patientId];

    if (sample == null) {
      throw const PatientsException(
        'No prescriptions are available for this patient yet.',
      );
    }

    final all = [
      ...sample,
      ...await _loadAddedPrescriptions(patientId),
    ];

    all.sort((a, b) => b.startDate.compareTo(a.startDate));

    return all;
  }

  Future<void> addPrescription(
    String patientId,
    DoctorPrescription prescription,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't save this prescription. Check your connection and try again.",
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_addedPrescriptionsPrefix$patientId';

    final saved = List<String>.from(
      prefs.getStringList(key) ?? const <String>[],
    );

    saved.add(jsonEncode(prescription.toJson()));

    await prefs.setStringList(key, saved);
  }

  Future<List<DoctorPrescription>> _loadAddedPrescriptions(
    String patientId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(
          '$_addedPrescriptionsPrefix$patientId',
        ) ??
        const <String>[];

    return [
      for (final json in saved)
        DoctorPrescription.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        ),
    ];
  }
}
