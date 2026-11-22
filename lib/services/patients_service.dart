import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient.dart';
import '../models/patient_detail.dart';
import '../models/patient_lab_result.dart';
import '../models/patient_record.dart';
import '../models/prescription.dart';
import '../models/vital_sign.dart';
import 'dashboard_service.dart';

/// Thrown when the patients could not be loaded. The screen shows [message]
/// in its error state.
class PatientsException implements Exception {
  const PatientsException(this.message);
  final String message;
}

/// Loads the doctor's patients for the Patients tab.
///
/// MOCK for now: it waits a little (to show the loading state) and returns
/// sample data. When the backend is ready, replace only the body of
/// [fetchPatients]; the screen does not need to change.
class PatientsService {
  PatientsService._();
  static final PatientsService instance = PatientsService._();

  /// Returns every patient (active and history), most recent visit first.
  ///
  /// Reuses the demo switch from Home (long-press the avatar) so the empty
  /// and error states can be shown during the presentation.
  Future<List<Patient>> fetchPatients() async {
    // Simulated network delay, so the skeleton is visible.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const PatientsException(
          "We couldn't load your patients. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const <Patient>[];
      case DemoScenario.normal:
        // Sample data. The first three are the patients in the prototype;
        // the History one is added so that pill has something to show.
        final patients = <Patient>[
          Patient(
            id: 'PAT-101',
            name: 'Jahna Erika Lagne',
            age: 21,
            sex: 'Female',
            phone: '+63 912 345 6789',
            condition: 'Common Cold',
            lastVisit: DateTime(2026, 9, 12),
            isActive: true,
          ),
          Patient(
            id: 'PAT-102',
            name: 'Juan Dae',
            age: 45,
            sex: 'Male',
            phone: '+63 917 222 3344',
            condition: 'Hypertension',
            lastVisit: DateTime(2025, 5, 15),
            isActive: true,
          ),
          Patient(
            id: 'PAT-103',
            name: 'Beabadoobee',
            age: 26,
            sex: 'Female',
            phone: '+63 905 876 5432',
            condition: 'Diarrhea',
            lastVisit: DateTime(2026, 9, 10),
            isActive: true,
          ),
          Patient(
            id: 'PAT-104',
            name: 'Carlos Reyes',
            age: 38,
            sex: 'Male',
            phone: '+63 928 111 2200',
            condition: 'Asthma',
            lastVisit: DateTime(2025, 3, 3),
            isActive: false,
          ),
        ];
        // Most recent visit first, so the order never depends on the data order.
        patients.sort((a, b) => b.lastVisit.compareTo(a.lastVisit));
        return patients;
    }
  }

  /// Returns the medical conditions and allergies of one patient.
  ///
  /// Mock data for now. Throws [PatientsException] in the Error demo scenario,
  /// or if no patient has that [patientId].
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
      throw const PatientsException('This patient could not be found.');
    }
    return detail;
  }

  /// Returns the medical history, allergies, immunizations and latest vitals
  /// of one patient (the "Records" pill of Patient Records).
  ///
  /// Mock data for now. Throws [PatientsException] in the Error demo scenario,
  /// or if no patient has that [patientId].
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
        vitals: _vitals(DateTime(2026, 9, 12), systolic: 120, diastolic: 60, heartRate: 72, weightKg: 68),
      ),
      'PAT-102': PatientRecord(
        patientId: 'PAT-102',
        history: const [MedicalHistoryEntry(condition: 'Hypertension', diagnosedYear: 2019)],
        allergies: const ['Penicillin'],
        immunizations: const ['Influenza (2024)'],
        vitals: _vitals(DateTime(2025, 5, 15), systolic: 148, diastolic: 92, heartRate: 80, weightKg: 82),
      ),
      'PAT-103': PatientRecord(
        patientId: 'PAT-103',
        history: const [MedicalHistoryEntry(condition: 'Diarrhea', diagnosedYear: 2026)],
        allergies: const [],
        immunizations: const [],
        vitals: _vitals(DateTime(2026, 9, 10), systolic: 110, diastolic: 70, heartRate: 78, weightKg: 55),
      ),
      'PAT-104': PatientRecord(
        patientId: 'PAT-104',
        history: const [MedicalHistoryEntry(condition: 'Asthma', diagnosedYear: 2018)],
        allergies: const ['Dust', 'Pollen'],
        immunizations: const ['Influenza (2023)'],
        vitals: _vitals(DateTime(2025, 3, 3), systolic: 118, diastolic: 76, heartRate: 74, weightKg: 70),
      ),
    };

    final record = records[patientId];
    if (record == null) {
      throw const PatientsException('This record could not be found.');
    }
    return record;
  }

  /// Builds the three vitals the doctor sees (blood pressure, heart rate,
  /// weight) as [VitalSign]s, the same model the patient's Home screen uses.
  /// Each has a single reading taken on [date].
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
        readings: [VitalReading(date: date, value: systolic, secondary: diastolic)],
      ),
      VitalSign(
        type: VitalType.heartRate,
        label: 'Heart Rate',
        unit: 'bpm',
        readings: [VitalReading(date: date, value: heartRate)],
      ),
      VitalSign(
        type: VitalType.weight,
        label: 'Weight',
        unit: 'kg',
        readings: [VitalReading(date: date, value: weightKg)],
      ),
    ];
  }

  /// Returns the lab results of one patient, newest first (the "Lab Results"
  /// pill of Patient Records).
  ///
  /// Mock data for now. A known patient with no lab results returns an empty
  /// list (shows the empty state). Throws [PatientsException] in the Error
  /// demo scenario, or if no patient has that [patientId].
  Future<List<PatientLabResult>> fetchPatientLabResults(String patientId) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't load these lab results. Check your connection and try again.",
      );
    }

    final results = <String, List<PatientLabResult>>{
      'PAT-101': [
        PatientLabResult(id: 'lab-001', testName: 'Complete Blood Count', date: DateTime(2026, 9, 8)),
        PatientLabResult(id: 'lab-002', testName: 'Lipid Profile', date: DateTime(2026, 8, 28)),
        PatientLabResult(id: 'lab-003', testName: 'Urinalysis', date: DateTime(2026, 8, 12)),
      ],
      'PAT-102': [
        PatientLabResult(id: 'lab-201', testName: 'Lipid Profile', date: DateTime(2025, 5, 15)),
      ],
      // A patient with no lab results, so the empty state can be demoed.
      'PAT-103': <PatientLabResult>[],
      'PAT-104': [
        PatientLabResult(id: 'lab-401', testName: 'Complete Blood Count', date: DateTime(2025, 3, 3)),
      ],
    };

    final list = results[patientId];
    if (list == null) {
      throw const PatientsException('This patient could not be found.');
    }
    // Newest first, so the order never depends on the data order.
    return [...list]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Key prefix for the prescriptions the doctor adds (one list per patient),
  /// saved in shared_preferences like the patient's own vital entries.
  static const String _addedPrescriptionsPrefix = 'added_prescriptions_';

  /// Returns the prescriptions of one patient, newest first (the
  /// "Prescriptions" pill of Patient Records): the sample ones plus the ones
  /// the doctor added with Add Prescription.
  ///
  /// A known patient with no prescriptions returns an empty list (shows the
  /// empty state). Throws [PatientsException] in the Error demo scenario, or
  /// if no patient has that [patientId].
  Future<List<Prescription>> fetchPatientPrescriptions(String patientId) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't load these prescriptions. Check your connection and try again.",
      );
    }

    // Sample data. Replace with a backend call later.
    final samples = <String, List<Prescription>>{
      'PAT-101': [
        Prescription(
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
        Prescription(
          id: 'rx-101-2',
          medicineName: 'Paracetamol',
          dosage: '500mg',
          form: 'capsule',
          timesPerDay: 4,
          durationDays: 5,
          startDate: DateTime(2026, 9, 11),
          refillDate: DateTime(2026, 10, 12),
        ),
        Prescription(
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
        Prescription(
          id: 'rx-102-1',
          medicineName: 'Amlodipine',
          dosage: '5mg',
          form: 'tablet',
          timesPerDay: 1,
          durationDays: 30,
          startDate: DateTime(2025, 5, 15),
          refillDate: DateTime(2025, 6, 14),
        ),
        Prescription(
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
        Prescription(
          id: 'rx-103-1',
          medicineName: 'Loperamide',
          dosage: '2mg',
          form: 'capsule',
          timesPerDay: 3,
          durationDays: 3,
          startDate: DateTime(2026, 9, 10),
        ),
      ],
      // A patient with no sample prescriptions, so the empty state can be demoed.
      'PAT-104': <Prescription>[],
    };

    final sample = samples[patientId];
    if (sample == null) {
      throw const PatientsException('This patient could not be found.');
    }

    // Newest start date first, so the order never depends on the data order.
    final all = [...sample, ...await _loadAddedPrescriptions(patientId)];
    all.sort((a, b) => b.startDate.compareTo(a.startDate));
    return all;
  }

  /// Saves a new prescription for a patient (Add Prescription > Save).
  ///
  /// It is stored on the device (shared_preferences), so it is still there
  /// after the app restarts and shows up in [fetchPatientPrescriptions].
  /// Throws [PatientsException] in the Error demo scenario.
  Future<void> addPrescription(String patientId, Prescription prescription) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PatientsException(
        "We couldn't save this prescription. Check your connection and try again.",
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_addedPrescriptionsPrefix$patientId';
    final saved = List<String>.from(prefs.getStringList(key) ?? const <String>[]);
    saved.add(jsonEncode(prescription.toJson()));
    await prefs.setStringList(key, saved);
  }

  /// Reads back the prescriptions the doctor added for one patient.
  Future<List<Prescription>> _loadAddedPrescriptions(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('$_addedPrescriptionsPrefix$patientId') ?? const <String>[];
    return [
      for (final json in saved)
        Prescription.fromJson(jsonDecode(json) as Map<String, dynamic>),
    ];
  }
}
