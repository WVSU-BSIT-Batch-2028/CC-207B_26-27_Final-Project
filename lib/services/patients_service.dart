import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/doctor_prescription.dart';
import '../models/patient.dart';
import '../models/patient_detail.dart';
import '../models/patient_lab_result.dart';
import '../models/patient_record.dart';
import '../models/vital_sign.dart';
import 'dashboard_service.dart';

/// Thrown when patient information cannot be loaded or saved.
class PatientsException implements Exception {
  const PatientsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PatientsService {
  PatientsService._();

  static final PatientsService instance = PatientsService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // PATIENT LIST
  // ---------------------------------------------------------------------------

  /// Returns the signed-in doctor's patients, including active and historical
  /// patients, sorted by most recent visit.
  ///
  /// Patients are associated with the doctor through their appointments,
  /// consultations, lab results, or prescriptions.
  ///
  /// Every initial query is filtered by doctorId so that a doctor cannot
  /// retrieve another doctor's patient list.
  Future<List<Patient>> fetchPatients() async {
    _demoThrowsIfError(
      "We couldn't load your patients. Check your connection and try again.",
    );

    if (_demoIsEmpty()) return const <Patient>[];

    final doctorId = _doctorUid();

    return _guard(() async {
      Future<QuerySnapshot<Map<String, dynamic>>> mine(String collection) {
        return _db
            .collection(collection)
            .where('doctorId', isEqualTo: doctorId)
            .get();
      }

      final results = await Future.wait([
        mine('appointments'),
        mine('consultations'),
        mine('labResults'),
        mine('prescriptions'),
      ]);

      final appointments = results[0];
      final consultations = results[1];

      // Collect unique patient IDs associated with this doctor.
      final patientIds = <String>{
        for (final doc in appointments.docs)
          if (doc.data()['status'] != 'cancelled')
            ..._idList(doc.data()['patientId']),
        for (final result in results.skip(1))
          for (final doc in result.docs) ..._idList(doc.data()['patientId']),
      };

      // Find the most recent consultation date for each patient.
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

      // Retrieve each patient's account and profile.
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

        // Ignore missing accounts and accounts that are not patients.
        if (userData == null || userData['role'] != 'patient') {
          continue;
        }

        patients.add(
          toPatient(
            user.id,
            userData,
            pair[1].data(),
            lastVisitById[user.id],
          ),
        );
      }

      // Patients with a recorded visit appear first.
      // Patients without a visit are sorted alphabetically afterward.
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

      return List.unmodifiable(patients);
    });
  }

  // ---------------------------------------------------------------------------
  // PATIENT DETAILS
  // ---------------------------------------------------------------------------

  /// Returns the medical conditions and allergies of one patient.
  Future<PatientDetail> fetchPatientDetail(String patientId) async {
    _demoThrowsIfError(
      "We couldn't load this patient. Check your connection and try again.",
    );

    return _guard(() async {
      final profile = await _profile(patientId);

      // Add the main condition first, followed by medical history.
      // Avoid duplicate condition names.
      final conditions = <String>[];

      final mainCondition = _text(profile?['condition'], '');

      if (mainCondition.isNotEmpty) {
        conditions.add(mainCondition);
      }

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

  /// Returns the medical history, allergies, immunizations, and latest
  /// available vital readings of one patient.
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

  // ---------------------------------------------------------------------------
  // LAB RESULTS
  // ---------------------------------------------------------------------------

  /// Returns the patient's lab results, newest first.
  Future<List<PatientLabResult>> fetchPatientLabResults(
    String patientId,
  ) async {
    _demoThrowsIfError(
      "We couldn't load these lab results. Check your connection and try again.",
    );

    return _guard(() async {
      final snapshot = await _db
          .collection('labResults')
          .where('patientId', isEqualTo: patientId)
          .get();

      final results = <PatientLabResult>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = _toDate(data['date']);

        // Skip documents without a valid date.
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

  // ---------------------------------------------------------------------------
  // PRESCRIPTIONS
  // ---------------------------------------------------------------------------

  /// Returns the patient's prescriptions, newest first.
  Future<List<DoctorPrescription>> fetchPatientPrescriptions(
    String patientId,
  ) async {
    _demoThrowsIfError(
      "We couldn't load these prescriptions. Check your connection and try again.",
    );

    return _guard(() async {
      final snapshot = await _db
          .collection('prescriptions')
          .where('patientId', isEqualTo: patientId)
          .get();

      final prescriptions = <DoctorPrescription>[];

      for (final doc in snapshot.docs) {
        final prescription = toPrescription(doc.id, doc.data());

        if (prescription != null) {
          prescriptions.add(prescription);
        }
      }

      prescriptions.sort(
        (a, b) => b.startDate.compareTo(a.startDate),
      );

      return prescriptions;
    });
  }

  /// Saves a new prescription to the Firestore prescriptions collection.
  Future<void> addPrescription(
    String patientId,
    DoctorPrescription prescription,
  ) async {
    _demoThrowsIfError(
      "We couldn't save this prescription. Check your connection and try again.",
    );

    await _guard<void>(() async {
      final doctorName = await _currentDoctorName();

      final endDate = prescription.startDate.add(
        Duration(days: prescription.durationDays),
      );

      await _db.collection('prescriptions').doc(prescription.id).set({
        'patientId': patientId,
        'doctorId': _doctorUid(),
        'medicine': prescription.medicineName,
        'dosage': prescription.dosage,
        'frequency': '${prescription.timesPerDay}x a day',
        'notes': prescription.notes ?? '',
        'startDate': Timestamp.fromDate(prescription.startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': 'active',
        'doctorName': doctorName,

        // Additional fields used by the doctor's prescription list.
        'form': prescription.form,
        'timesPerDay': prescription.timesPerDay,
        'durationDays': prescription.durationDays,
        'refillDate': prescription.refillDate == null
            ? null
            : Timestamp.fromDate(prescription.refillDate!),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // CONSULTATION NOTES
  // ---------------------------------------------------------------------------

  /// Saves consultation notes to the Firestore consultations collection.
  ///
  /// The saved information can be used by the patient's consultation records
  /// and to determine the patient's latest visit.
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

        // Additional fields used by the consultation details view.
        'department': department,
        'type': 'Consultation',
        'diagnosis': diagnosis,
        'treatment': treatment,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE MAPPING HELPERS
  // ---------------------------------------------------------------------------

  /// Retrieves a patient's profile document, or null if no profile exists.
  Future<Map<String, dynamic>?> _profile(String patientId) async {
    final snapshot =
        await _db.collection('patientProfiles').doc(patientId).get();

    return snapshot.data();
  }

  /// Converts a Firestore user and patient profile into a Patient model.
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

  /// Converts the profile's medicalHistory list into medical history entries.
  @visibleForTesting
  List<MedicalHistoryEntry> historyOf(
    Map<String, dynamic>? profile,
  ) {
    final raw = profile?['medicalHistory'];

    if (raw is! List) {
      return const <MedicalHistoryEntry>[];
    }

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

  // ---------------------------------------------------------------------------
  // VITAL SIGNS
  // ---------------------------------------------------------------------------

  /// Retrieves the latest available vital readings for a patient.
  ///
  /// If vital readings cannot be accessed, an empty list is returned so the
  /// remaining patient record can still be displayed.
  Future<List<VitalSign>> _loadVitals(String patientId) async {
    try {
      final snapshot = await _db
          .collection('vitalReadings')
          .where('patientId', isEqualTo: patientId)
          .get();

      final byType = <VitalType, List<VitalReading>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final type = vitalTypeFrom(data['type']);
        final date = _toDate(data['date']);
        final value = data['value'];

        if (type == null || date == null || value is! num) {
          continue;
        }

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
              readings: byType[type]!..sort((a, b) => a.date.compareTo(b.date)),
            ),
      ];
    } on FirebaseException {
      return const <VitalSign>[];
    }
  }

  /// Converts different vital type formats into a VitalType.
  ///
  /// For example, "bloodPressure", "blood_pressure", and "Blood Pressure"
  /// are treated as the same type.
  @visibleForTesting
  VitalType? vitalTypeFrom(Object? raw) {
    final text =
        raw?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

    for (final type in VitalType.values) {
      if (type.name.toLowerCase() == text) {
        return type;
      }
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

  // ---------------------------------------------------------------------------
  // PRESCRIPTION MAPPING HELPERS
  // ---------------------------------------------------------------------------

  /// Converts a Firestore prescription document into a DoctorPrescription.
  ///
  /// Supports both the main Firestore field names and the additional fields
  /// used by the doctor's prescription list.
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
        : end != null
            ? end.difference(start).inDays.clamp(1, 3650).toInt()
            : 1;

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

  /// Converts frequency descriptions into a number of times per day.
  ///
  /// Examples:
  /// - "2x a day" returns 2.
  /// - "Twice a day" returns 2.
  /// - "Once a day" returns 1.
  @visibleForTesting
  int timesFromText(Object? raw) {
    final text = raw?.toString().toLowerCase() ?? '';

    final number = RegExp(r'\d+').firstMatch(text);

    if (number != null) {
      return int.parse(number.group(0)!);
    }

    if (text.contains('twice')) {
      return 2;
    }

    return 1;
  }

  // ---------------------------------------------------------------------------
  // GENERAL HELPERS
  // ---------------------------------------------------------------------------

  /// Converts a patient ID into a one-item list.
  /// Missing or invalid IDs return an empty list.
  List<String> _idList(Object? value) {
    return value is String && value.isNotEmpty ? [value] : const <String>[];
  }

  /// Returns the currently signed-in doctor's Firebase UID.
  String _doctorUid() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const PatientsException(
        'Please sign in again to see your patients.',
      );
    }

    return user.uid;
  }

  /// Retrieves the signed-in doctor's name from the users collection.
  Future<String> _currentDoctorName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return 'Doctor';

    final snapshot = await _db.collection('users').doc(user.uid).get();

    return _text(snapshot.data()?['fullName'], 'Doctor');
  }

  /// Runs a Firestore operation and converts Firebase errors into
  /// user-friendly PatientsException messages.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PatientsException {
      rethrow;
    } on FirebaseException catch (e) {
      throw PatientsException(_messageFor(e));
    }
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
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

  /// Converts a Firestore Timestamp, DateTime, or ISO date string into
  /// a DateTime value.
  DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    return null;
  }

  /// Converts a value into trimmed text, using a fallback when empty.
  String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  /// Converts a Firestore list into a list of non-empty strings.
  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }

  // ---------------------------------------------------------------------------
  // DEMO SCENARIO HELPERS
  // ---------------------------------------------------------------------------

  /// Returns true when the Empty demo scenario is selected.
  bool _demoIsEmpty() {
    return DashboardService.instance.scenario == DemoScenario.empty;
  }

  /// Throws a PatientsException when the Error demo scenario is selected.
  void _demoThrowsIfError(String message) {
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw PatientsException(message);
    }
  }
}
