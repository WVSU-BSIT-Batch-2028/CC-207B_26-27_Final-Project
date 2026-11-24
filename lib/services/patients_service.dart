import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/doctor_prescription.dart';
import '../models/patient.dart';
import '../models/patient_detail.dart';
import '../models/patient_lab_result.dart';
import '../models/patient_profile.dart';
import '../models/patient_record.dart';
import '../models/refill_request.dart';
import '../models/taken_history.dart';
import '../models/vital_sign.dart';
import 'dashboard_service.dart';
import 'prescription_service.dart';

/// Thrown when the patients could not be loaded. The screen shows [message]
/// in its error state.
class PatientsException implements Exception {
  const PatientsException(this.message);
  final String message;
}

/// Loads the doctor's patients and their records from Firestore.
///
/// Collections (see FIRESTORE_PLAN.md):
/// - `users/{uid}`: fullName and role. Patients are the users whose role is "patient".
/// - `patientProfiles/{uid}`: age, sex, phone, condition, isActive, allergies,
///   immunizations, medicalHistory.
/// - `consultations/{id}`: the latest one gives a patient's last visit.
/// - `labResults/{id}`, `prescriptions/{id}`, `vitalReadings/{id}`: read with
///   `where('patientId', isEqualTo: patientId)`.
///
/// Search and filtering happen in the app on the loaded list (Firestore has no
/// text search), and lists are sorted here, so no Firestore index is needed.
/// The screens do not change: they only call these methods.
class PatientsService {
  PatientsService._();
  static final PatientsService instance = PatientsService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Returns the signed-in doctor's own patients (active and history), most
  /// recent visit first.
  ///
  /// A patient belongs to a doctor when either:
  /// - the patient has a (not cancelled) appointment whose `doctorId` is this
  ///   doctor's uid, or
  /// - this doctor already wrote a consultation, lab result or prescription
  ///   for the patient (those documents carry the doctor's `doctorId`).
  ///
  /// Every query filters by `doctorId == uid`, so one doctor never loads
  /// another doctor's patients. Then one read per patient gets the account
  /// and the profile. The last visit comes from this doctor's consultations.
  ///
  /// Reuses the demo switch from Home (long-press the avatar) so the empty
  /// and error states can still be shown during the presentation.
  Future<List<Patient>> fetchPatients() async {
    _demoThrowsIfError(
      "We couldn't load your patients. Check your connection and try again.",
    );
    if (_demoIsEmpty()) return const <Patient>[];
    final doctorId = _doctorUid();

    return _guard(() async {
      Future<QuerySnapshot<Map<String, dynamic>>> mine(String collection) =>
          _db.collection(collection).where('doctorId', isEqualTo: doctorId).get();

      final results = await Future.wait([
        mine('appointments'),
        mine('consultations'),
        mine('labResults'),
        mine('prescriptions'),
      ]);
      final consultations = results[1];

      // The uids of this doctor's patients.
      final patientIds = <String>{
        for (final doc in results[0].docs)
          if (doc.data()['status'] != 'cancelled')
            ..._idList(doc.data()['patientId']),
        for (final result in results.skip(1))
          for (final doc in result.docs)
            ..._idList(doc.data()['patientId']),
      };

      // Each patient's most recent consultation date (with this doctor).
      final lastVisitById = <String, DateTime>{};
      for (final doc in consultations.docs) {
        final data = doc.data();
        final patientId = data['patientId'];
        final date = _toDate(data['date']);
        if (patientId is! String || date == null) continue;
        final current = lastVisitById[patientId];
        if (current == null || date.isAfter(current)) {
          lastVisitById[patientId] = date;
        }
      }

      // One account + one profile read per patient.
      final loaded = await Future.wait([
        for (final id in patientIds)
          Future.wait([
            _db.collection('users').doc(id).get(),
            _db.collection('patientProfiles').doc(id).get(),
          ]),
      ]);

      final patients = <Patient>[];
      for (final pair in loaded) {
        final user = pair[0];
        final userData = user.data();

        // Skip an id with no account, or an account that is not a patient.
        if (userData == null || userData['role'] != 'patient') continue;

        patients.add(
          toPatient(
            user.id,
            userData,
            pair[1].data(),
            lastVisitById[user.id],
          ),
        );
      }

      // Most recent visit first; patients with no visit yet go last, by name.
      patients.sort((a, b) {
        final aVisit = a.lastVisit;
        final bVisit = b.lastVisit;
        if (aVisit == null && bVisit == null) {
          return a.name.compareTo(b.name);
        }
        if (aVisit == null) return 1;
        if (bVisit == null) return -1;
        return bVisit.compareTo(aVisit);
      });
      return patients;
    });
  }

  /// Returns the medical conditions and allergies of one patient (from the
  /// patient's profile). A patient with no profile has empty lists.
  Future<PatientDetail> fetchPatientDetail(String patientId) async {
    _demoThrowsIfError(
      "We couldn't load this patient. Check your connection and try again.",
    );

    return _guard(() async {
      final profile = await _profile(patientId);

      // The main condition first, then the history, without repeats.
      final conditions = <String>[];
      final main = _text(profile?['condition'], '');
      if (main.isNotEmpty) conditions.add(main);
      for (final entry in historyOf(profile)) {
        if (!conditions.contains(entry.condition)) {
          conditions.add(entry.condition);
        }
      }

      return PatientDetail(
        patientId: patientId,
        conditions: conditions,
        allergies: _stringList(profile?['allergies']),
      );
    });
  }

  /// Returns the medical history, allergies, immunizations and latest vitals
  /// of a patient (the "Records" pill of Patient Records).
  Future<PatientRecord> fetchPatientRecord(String patientId) async {
    _demoThrowsIfError(
      "We couldn't load this record. Check your connection and try again.",
    );

    return _guard(() async {
      final profile = await _profile(patientId);
      final vitals = await _loadVitals(patientId);

      return PatientRecord(
        patientId: patientId,
        history: historyOf(profile),
        allergies: _stringList(profile?['allergies']),
        immunizations: _stringList(profile?['immunizations']),
        vitals: vitals,
      );
    });
  }

  /// Returns the lab results of one patient, newest first (the "Lab Results"
  /// pill of Patient Records). The full result opens from its id.
  Future<List<PatientLabResult>> fetchPatientLabResults(String patientId) async {
    _demoThrowsIfError(
      "We couldn't load these lab results. Check your connection and try again.",
    );

    return _guard(() async {
      final snap = await _db
          .collection('labResults')
          .where('patientId', isEqualTo: patientId)
          .get();

      final results = <PatientLabResult>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = _toDate(data['date']);
        if (date == null) continue;

        results.add(
          PatientLabResult(
            id: doc.id,
            testName: _text(data['name'], 'Lab Result'),
            date: date,
          ),
        );
      }

      results.sort((a, b) => b.date.compareTo(a.date));
      return results;
    });
  }

  /// Returns the prescriptions of one patient, newest first (the
  /// "Prescriptions" pill of Patient Records).
  Future<List<DoctorPrescription>> fetchPatientPrescriptions(
    String patientId,
  ) async {
    _demoThrowsIfError(
      "We couldn't load these prescriptions. Check your connection and try again.",
    );

    return _guard(() async {
      final snap = await _db
          .collection('prescriptions')
          .where('patientId', isEqualTo: patientId)
          .get();

      final prescriptions = <DoctorPrescription>[];
      for (final doc in snap.docs) {
        final prescription = toPrescription(doc.id, doc.data());
        if (prescription != null) prescriptions.add(prescription);
      }

      prescriptions.sort((a, b) => b.startDate.compareTo(a.startDate));
      return prescriptions;
    });
  }

  /// Saves a new prescription for a patient (Add Prescription > Save).
  ///
  /// Hands the save to PrescriptionService, the writer used by the patient
  /// screens and the refill workflow.
  ///
  /// Throws [PatientsException] if it could not be saved.
  Future<void> addPrescription(
    String patientId,
    DoctorPrescription prescription,
  ) async {
    _demoThrowsIfError(
      "We couldn't save this prescription. Check your connection and try again.",
    );

    try {
      await PrescriptionService.instance.addPrescription(
        patientId,
        prescription,
      );
    } on PrescriptionException catch (e) {
      throw PatientsException(e.message);
    }
  }

  /// Returns the refill requests this patient sent, keyed by prescription id
  /// (shown under each prescription on the doctor's Prescriptions pill).
  ///
  /// Throws [PatientsException] if they could not be loaded.
  Future<Map<String, RefillRequest>> fetchPatientRefillRequests(
    String patientId,
  ) async {
    _demoThrowsIfError(
      "We couldn't load the refill requests. Check your connection and try again.",
    );

    try {
      return await PrescriptionService.instance
          .fetchRefillRequestsForPatient(patientId);
    } on PrescriptionException catch (e) {
      throw PatientsException(e.message);
    }
  }

  /// Returns the days this patient marked each prescription as taken, keyed
  /// by prescription id (shown under each prescription for the doctor).
  ///
  /// Throws [PatientsException] if they could not be loaded.
  Future<Map<String, TakenHistory>> fetchPatientTakenHistory(
    String patientId,
  ) async {
    _demoThrowsIfError(
      "We couldn't load the doses taken. Check your connection and try again.",
    );

    try {
      return await PrescriptionService.instance
          .fetchTakenHistoryForPatient(patientId);
    } on PrescriptionException catch (e) {
      throw PatientsException(e.message);
    }
  }

  /// Records the doctor's answer (approve or decline) to a patient's refill
  /// request. Returns null when it worked, or the error message to show.
  /// This is the shape RefillRequestCard expects from its `onRespond`.
  Future<String?> answerPatientRefill({
    required String patientId,
    required String prescriptionId,
    required RefillStatus answer,
  }) async {
    try {
      await PrescriptionService.instance.respondToRefill(
        patientId: patientId,
        prescriptionId: prescriptionId,
        answer: answer,
      );
      return null;
    } on PrescriptionException catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      return _messageFor(e);
    }
  }

  /// Saves new consultation notes for a patient (Add Consultation Notes >
  /// Save) in the `consultations` collection.
  ///
  /// It writes the fields of FIRESTORE_PLAN.md (patientId, appointmentId,
  /// doctorName, date, notes) plus the ones the patient's Consultation Details
  /// popup shows (department, type, diagnosis, treatment). [appointmentId] is
  /// empty until the notes are linked to an appointment. The patient sees the
  /// notes in Records > Consultations, and the patient's last visit in the
  /// Patients list is updated. Throws [PatientsException] if it could not be saved.
  Future<void> addConsultationNote(
    String patientId, {
    required String department,
    required DateTime date,
    required String diagnosis,
    required String treatment,
    String appointmentId = '',
  }) async {
    _demoThrowsIfError(
      "We couldn't save these notes. Check your connection and try again.",
    );

    await _guard<void>(() async {
      final doctorName = await _currentDoctorName();
      await _db.collection('consultations').doc().set({
        'patientId': patientId,
        'doctorId': _doctorUid(),
        'appointmentId': appointmentId,
        'doctorName': doctorName,
        'date': Timestamp.fromDate(date),
        'notes': 'Assessment: $diagnosis\nTreatment: $treatment',
        'department': department,
        'type': 'Consultation',
        'diagnosis': diagnosis,
        'treatment': treatment,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// The patient's medical profile, for the Edit Patient Info form.
  /// A patient with no `patientProfiles` document gets an empty profile.
  Future<PatientProfile> fetchPatientProfile(String patientId) async {
    _demoThrowsIfError(
      "We couldn't load this patient's details. Check your connection and try again.",
    );
    return _guard(() async => PatientProfile.fromMap(await _profile(patientId)));
  }

  /// Saves the patient's medical profile (Edit Patient Info > Save) in
  /// `patientProfiles/{uid}`. The rules let only doctors write it.
  ///
  /// Returns the updated [Patient] summary so the screens can show the new
  /// age, sex, phone, condition and status without reloading the list.
  /// Throws [PatientsException] if it could not be saved.
  Future<Patient> savePatientProfile(Patient patient, PatientProfile profile) async {
    _demoThrowsIfError(
      "We couldn't save this patient's details. Check your connection and try again.",
    );

    await _guard<void>(() async {
      await _db.collection('patientProfiles').doc(patient.id).set({
        ...profile.toMap(),
        'updatedBy': _doctorUid(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return Patient(
      id: patient.id,
      name: patient.name,
      condition: profile.condition.isEmpty ? 'No condition recorded' : profile.condition,
      isActive: profile.isActive,
      age: profile.age,
      sex: profile.sex.isEmpty ? null : profile.sex,
      phone: profile.phone.isEmpty ? null : profile.phone,
      lastVisit: patient.lastVisit,
    );
  }

  /// Saves a lab result for a patient (Add Lab Result > Save) in the
  /// `labResults` collection. The patient sees it in Records > Lab Results
  /// and the doctor in Patient Records > Lab Results.
  ///
  /// [values] are maps of name, value, unit, range and flag (what
  /// LabValue.fromMap reads). Saved results are not edited afterwards.
  /// Throws [PatientsException] if it could not be saved.
  Future<void> addLabResult(
    String patientId, {
    required String testName,
    required DateTime date,
    required List<Map<String, dynamic>> values,
    required String overallResult,
    String doctorNotes = '',
  }) async {
    _demoThrowsIfError(
      "We couldn't save this lab result. Check your connection and try again.",
    );

    await _guard<void>(() async {
      final doctorName = await _currentDoctorName();
      await _db.collection('labResults').doc().set({
        'patientId': patientId,
        'doctorId': _doctorUid(),
        'name': testName,
        'date': Timestamp.fromDate(date),
        'status': 'Complete',
        'enteredBy': doctorName,
        'overallResult': overallResult,
        'doctorNotes': doctorNotes,
        'values': values,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------- helpers

  /// One patient's profile document, or null if the patient has none yet.
  Future<Map<String, dynamic>?> _profile(String patientId) async {
    final snap = await _db.collection('patientProfiles').doc(patientId).get();
    return snap.data();
  }

  /// Builds a [Patient] from the account, the optional profile and the last visit.
  @visibleForTesting
  Patient toPatient(
    String uid,
    Map<String, dynamic> user,
    Map<String, dynamic>? profile,
    DateTime? lastVisit,
  ) {
    final age = profile?['age'];
    final sex = _text(profile?['sex'], '');
    final phone = _text(profile?['phone'], '');
    return Patient(
      id: uid,
      name: _text(user['fullName'], 'Unnamed patient'),
      condition: _text(profile?['condition'], 'No condition recorded'),
      isActive: profile?['isActive'] != false,
      age: age is num ? age.toInt() : null,
      sex: sex.isEmpty ? null : sex,
      phone: phone.isEmpty ? null : phone,
      lastVisit: lastVisit,
    );
  }

  /// The profile's `medicalHistory` list (maps of condition and diagnosedYear).
  @visibleForTesting
  List<MedicalHistoryEntry> historyOf(Map<String, dynamic>? profile) {
    final raw = profile?['medicalHistory'];
    if (raw is! List) return const <MedicalHistoryEntry>[];
    return [
      for (final item in raw)
        if (item is Map && _text(item['condition'], '').isNotEmpty)
          MedicalHistoryEntry(
            condition: _text(item['condition'], ''),
            diagnosedYear: item['diagnosedYear'] is num
                ? (item['diagnosedYear'] as num).toInt()
                : 0,
          ),
    ];
  }

  /// The latest vitals of a patient, one [VitalSign] per type, from the
  /// `vitalReadings` collection. If that collection cannot be read (for
  /// example the rules do not allow it yet), the vitals are simply empty.
  Future<List<VitalSign>> _loadVitals(String patientId) async {
    try {
      final snap = await _db
          .collection('vitalReadings')
          .where('patientId', isEqualTo: patientId)
          .get();

      final byType = <VitalType, List<VitalReading>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final type = vitalTypeFrom(data['type']);
        final date = _toDate(data['date']);
        final value = data['value'];
        if (type == null || date == null || value is! num) continue;

        final secondary = data['secondary'];
        byType.putIfAbsent(type, () => []).add(
          VitalReading(
            date: date,
            value: value.toDouble(),
            secondary: secondary is num ? secondary.toDouble() : null,
          ),
        );
      }

      const order = [
        VitalType.bloodPressure,
        VitalType.heartRate,
        VitalType.weight,
        VitalType.sleep,
      ];

      return [
        for (final type in order)
          if (byType[type] != null)
            VitalSign(
              type: type,
              label: _vitalLabel(type),
              unit: _vitalUnit(type),
              readings: (byType[type]!
                ..sort((a, b) => a.date.compareTo(b.date))),
            ),
      ];
    } on FirebaseException {
      return const <VitalSign>[];
    }
  }

  /// "bloodPressure", "blood_pressure" and "Blood Pressure" all mean the same type.
  @visibleForTesting
  VitalType? vitalTypeFrom(Object? raw) {
    final text = raw?.toString().toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    for (final type in VitalType.values) {
      if (type.name.toLowerCase() == text) return type;
    }
    return null;
  }

  String _vitalLabel(VitalType type) {
    switch (type) {
      case VitalType.heartRate:
        return 'Heart Rate';
      case VitalType.bloodPressure:
        return 'Blood Pressure';
      case VitalType.weight:
        return 'Weight';
      case VitalType.sleep:
        return 'Sleep';
    }
  }

  String _vitalUnit(VitalType type) {
    switch (type) {
      case VitalType.heartRate:
        return 'bpm';
      case VitalType.bloodPressure:
        return 'mmHg';
      case VitalType.weight:
        return 'kg';
      case VitalType.sleep:
        return 'hours';
    }
  }

  /// Builds a [DoctorPrescription] from a `prescriptions` document, or null if
  /// it has no start date. It accepts both the plan's fields (`medicine`,
  /// `frequency`, `endDate`) and the extras (`timesPerDay`, `durationDays`).
  @visibleForTesting
  DoctorPrescription? toPrescription(
    String id,
    Map<String, dynamic> data,
  ) {
    final start = _toDate(data['startDate']);
    if (start == null) return null;
    final end = _toDate(data['endDate']);

    final timesPerDay = data['timesPerDay'] is num
        ? (data['timesPerDay'] as num).toInt()
        : timesFromText(data['frequency']);

    final durationDays = data['durationDays'] is num
        ? (data['durationDays'] as num).toInt()
        : (end != null
            ? end.difference(start).inDays.clamp(1, 3650).toInt()
            : 1);

    final notes = _text(data['notes'], '');

    return DoctorPrescription(
      id: id,
      medicineName: _text(
        data['medicine'],
        _text(data['medicineName'], 'Medicine'),
      ),
      dosage: _text(data['dosage'], ''),
      form: _text(data['form'], 'dose'),
      timesPerDay: timesPerDay,
      durationDays: durationDays,
      startDate: start,
      refillDate: _toDate(data['refillDate']),
      notes: notes.isEmpty ? null : notes,
    );
  }

  /// "2x a day" -> 2, "Twice a day" -> 2, "Once a day" -> 1; 1 if unclear.
  @visibleForTesting
  int timesFromText(Object? raw) {
    final text = raw?.toString().toLowerCase() ?? '';
    final number = RegExp(r'\d+').firstMatch(text);
    if (number != null) return int.parse(number.group(0)!);
    if (text.contains('twice')) return 2;
    return 1;
  }

  /// A uid (text) as a one-item list, or an empty list when it is missing.
  List<String> _idList(Object? value) =>
      value is String && value.isNotEmpty ? [value] : const <String>[];

  /// The signed-in doctor's uid. Throws if nobody is signed in.
  String _doctorUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PatientsException(
        'Please sign in again to see your patients.',
      );
    }
    return user.uid;
  }

  /// The signed-in doctor's name from `users/{uid}`, or "Doctor".
  Future<String> _currentDoctorName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Doctor';
    final snap = await _db.collection('users').doc(user.uid).get();
    return _text(snap.data()?['fullName'], 'Doctor');
  }

  /// Runs a Firestore call and turns Firebase errors into a PatientsException.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw PatientsException(_messageFor(e));
    }
  }

  /// A friendly message for a Firebase error code.
  String _messageFor(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return "You don't have permission to do this. Ask the team to check the Firestore rules.";
      case 'unavailable':
        return 'No connection right now. Check your internet and try again.';
      case 'failed-precondition':
        return 'This list needs a Firestore index. Open the browser console (F12) and click the link in the error.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// A Firestore Timestamp (or DateTime or ISO text) as a DateTime, or null.
  DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// [value] as trimmed text, or [fallback] if it is missing or empty.
  String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  /// A Firestore list as a list of non-empty strings.
  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }

  /// True in the "Empty" demo scenario (long-press the avatar on Home).
  bool _demoIsEmpty() =>
      DashboardService.instance.scenario == DemoScenario.empty;

  /// Throws in the "Error" demo scenario, so the error state can be demoed.
  void _demoThrowsIfError(String message) {
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw PatientsException(message);
    }
  }
}
