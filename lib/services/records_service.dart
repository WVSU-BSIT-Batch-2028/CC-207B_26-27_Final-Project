import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/consultation_detail.dart';
import '../models/health_record.dart';
import '../models/lab_result_detail.dart';
import 'dashboard_service.dart';

/// Thrown when the records could not be loaded. The screen shows [message]
/// in its error state.
class RecordsException implements Exception {
  const RecordsException(this.message);
  final String message;
}

/// Loads a patient's records (consultations and lab results) from Firestore.
///
/// Collections (see FIRESTORE_PLAN.md):
/// - `consultations/{id}`: patientId, doctorName, department, type, date,
///   diagnosis, treatment (and notes).
/// - `labResults/{id}`: patientId, name, date, status, enteredBy,
///   overallResult, doctorNotes and a `values` list.
///
/// Every list is read with `where('patientId', isEqualTo: uid)` for the
/// signed-in patient, and sorted here in the app (so no Firestore index is
/// needed). The screens do not change: they only call these methods.
class RecordsService {
  RecordsService._();
  static final RecordsService instance = RecordsService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Returns all records of the signed-in patient, newest first.
  ///
  /// Reuses the demo switch from Home (long-press the avatar) so the empty and
  /// error states can still be shown during the presentation.
  Future<List<HealthRecord>> fetchRecords() async {
    _demoThrowsIfError("We couldn't load your records. Check your connection and try again.");
    if (_demoIsEmpty()) return const <HealthRecord>[];
    final uid = _signedInUid();

    return _guard(() async {
      final results = await Future.wait([
        _consultationRecords(uid),
        _labRecords(uid),
      ]);
      final records = [...results[0], ...results[1]];
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }

  /// Returns only the consultations, newest first (for the Consultations screen).
  Future<List<HealthRecord>> fetchConsultations() async {
    _demoThrowsIfError("We couldn't load your records. Check your connection and try again.");
    if (_demoIsEmpty()) return const <HealthRecord>[];
    final uid = _signedInUid();
    return _guard(() => _consultationRecords(uid));
  }

  /// Returns only the lab results, newest first (for the Lab Results screen).
  Future<List<HealthRecord>> fetchLabResults() async {
    _demoThrowsIfError("We couldn't load your records. Check your connection and try again.");
    if (_demoIsEmpty()) return const <HealthRecord>[];
    final uid = _signedInUid();
    return _guard(() => _labRecords(uid));
  }

  /// Returns the full medical record of one consultation (for the popup).
  ///
  /// Throws [RecordsException] if the document does not exist or cannot be read.
  Future<ConsultationDetail> fetchConsultationDetail(String id) async {
    _demoThrowsIfError("We couldn't load this medical record. Check your connection and try again.");

    return _guard(() async {
      final snap = await _db.collection('consultations').doc(id).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw const RecordsException('This medical record could not be found.');
      }
      return consultationDetailFrom(snap.id, data);
    });
  }

  /// Returns the full lab result (values, notes) for the popup.
  ///
  /// Used by the patient's Records and by the doctor's View Lab Results.
  /// Throws [RecordsException] if the document does not exist or cannot be read.
  Future<LabResultDetail> fetchLabResultDetail(String id) async {
    _demoThrowsIfError("We couldn't load this lab result. Check your connection and try again.");

    return _guard(() async {
      final snap = await _db.collection('labResults').doc(id).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw const RecordsException('This lab result could not be found.');
      }
      return labDetailFrom(snap.id, data, await _patientName(data['patientId']));
    });
  }

  // ---------------------------------------------------------------- helpers

  /// The consultations of one patient as list cards (sorted newest first).
  Future<List<HealthRecord>> _consultationRecords(String uid) async {
    final snap = await _db.collection('consultations').where('patientId', isEqualTo: uid).get();
    final records = <HealthRecord>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final record = consultationRecordFrom(doc.id, data);
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// The lab results of one patient as list cards (sorted newest first).
  Future<List<HealthRecord>> _labRecords(String uid) async {
    final snap = await _db.collection('labResults').where('patientId', isEqualTo: uid).get();
    final records = <HealthRecord>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final record = labRecordFrom(doc.id, data);
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// A consultation document as a list card, or null if it has no date.
  @visibleForTesting
  HealthRecord? consultationRecordFrom(String id, Map<String, dynamic> data) {
    final date = _toDate(data['date']);
    if (date == null) return null;
    return HealthRecord(
      id: id,
      type: RecordType.consultation,
      title: _text(data['department'], 'General Consultation'),
      subtitle: _text(data['doctorName'], 'Doctor'),
      date: date,
    );
  }

  /// A lab result document as a list card, or null if it has no date.
  @visibleForTesting
  HealthRecord? labRecordFrom(String id, Map<String, dynamic> data) {
    final date = _toDate(data['date']);
    if (date == null) return null;
    return HealthRecord(
      id: id,
      type: RecordType.labResult,
      title: 'Laboratory Results',
      subtitle: _text(data['name'], 'Lab Result'),
      date: date,
    );
  }

  /// A consultation document as the full popup data.
  /// Throws [RecordsException] if it has no date.
  @visibleForTesting
  ConsultationDetail consultationDetailFrom(String id, Map<String, dynamic> data) {
    final date = _toDate(data['date']);
    if (date == null) {
      throw const RecordsException('This medical record is incomplete.');
    }
    return ConsultationDetail(
      id: id,
      doctorName: _text(data['doctorName'], 'Not recorded'),
      department: _text(data['department'], 'General Consultation'),
      type: _text(data['type'], 'Consultation'),
      date: date,
      // The plan has a single `notes` field, so it is the fallback for the diagnosis.
      diagnosis: _text(data['diagnosis'], _text(data['notes'], 'No diagnosis recorded.')),
      treatment: _text(data['treatment'], 'No recommendations recorded.'),
    );
  }

  /// A lab result document as the full popup data.
  /// Throws [RecordsException] if it has no date.
  @visibleForTesting
  LabResultDetail labDetailFrom(String id, Map<String, dynamic> data, String patientName) {
    final date = _toDate(data['date']);
    if (date == null) {
      throw const RecordsException('This lab result is incomplete.');
    }
    final rawValues = data['values'];
    final values = <LabValue>[
      if (rawValues is List)
        for (final item in rawValues)
          if (item is Map) LabValue.fromMap(Map<String, dynamic>.from(item)),
    ];
    return LabResultDetail(
      id: id,
      testName: _text(data['name'], 'Lab Result'),
      patientName: patientName,
      requestedBy: _text(data['enteredBy'], 'Not recorded'),
      status: _text(data['status'], 'Complete'),
      date: date,
      results: values,
      overallResult: _text(data['overallResult'], 'No summary recorded.'),
      doctorNotes: _text(data['doctorNotes'], 'No notes recorded.'),
    );
  }

  /// The patient's full name from `users/{uid}`, or "Patient" if not found.
  Future<String> _patientName(Object? patientId) async {
    if (patientId is! String || patientId.isEmpty) return 'Patient';
    final snap = await _db.collection('users').doc(patientId).get();
    return _text(snap.data()?['fullName'], 'Patient');
  }

  /// The signed-in user's uid. Throws if nobody is signed in.
  String _signedInUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const RecordsException('Please sign in again to see your records.');
    }
    return user.uid;
  }

  /// Runs a Firestore call and turns Firebase errors into a [RecordsException]
  /// with a friendly message, so the screens show their normal error state.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw RecordsException(_messageFor(e));
    }
  }

  /// A friendly message for a Firebase error code.
  String _messageFor(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return "You don't have permission to view these records.";
      case 'unavailable':
        return 'No connection right now. Check your internet and try again.';
      case 'failed-precondition':
        return 'This list needs a Firestore index. Open the browser console (F12) and click the link in the error.';
      default:
        return "We couldn't load your records. Please try again.";
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

  /// True in the "Empty" demo scenario (long-press the avatar on Home).
  bool _demoIsEmpty() => DashboardService.instance.scenario == DemoScenario.empty;

  /// Throws in the "Error" demo scenario, so the error state can be demoed.
  void _demoThrowsIfError(String message) {
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw RecordsException(message);
    }
  }
}
