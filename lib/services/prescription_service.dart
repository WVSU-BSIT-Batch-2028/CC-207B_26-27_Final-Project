import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/date_format.dart';
import '../models/doctor_prescription.dart';
import '../models/medication_dose.dart';
import '../models/prescription.dart';
import '../models/refill_request.dart';
import '../models/reminder_setting.dart';
import '../models/taken_history.dart';
import '../models/user_role.dart';
import 'auth_service.dart';
import 'dashboard_service.dart';
import 'prescription_mapper.dart';

/// Error shown to the user when prescription data cannot be loaded or saved.
class PrescriptionException implements Exception {
  const PrescriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What has happened with one prescription (used by Prescription Details):
/// was it marked as taken today, and is there a refill request?
class PrescriptionActivity {
  const PrescriptionActivity({required this.takenToday, this.refillRequest});

  final bool takenToday;
  final RefillRequest? refillRequest;
}

/// The one place every Prescriptions screen (patient, doctor and Home) goes
/// through. It reads and writes Firestore, so both sides share one record.
///
/// Collections (all documents carry a `patientId`):
///   prescriptions/{id}                 the prescription itself
///   refillRequests/{patientId}_{rxId}  the patient's refill request + answer
///   reminders/{patientId}_{rxId}       the patient's saved reminder
///   doseLogs/{patientId}_{yyyy-MM-dd}  prescription ids taken that day
///
/// `patientId` is the signed-in patient's uid, unless the patient's
/// `users/{uid}` document has a `patientId` field (for example "PAT-101").
/// That link lets a demo patient account see prescriptions the doctor wrote
/// for a patient in the doctor's (still mock) Patients list.
class PrescriptionService {
  PrescriptionService._();

  /// One shared instance used by every Prescriptions screen.
  static final PrescriptionService instance = PrescriptionService._();

  final AuthService _auth = AuthService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _prescriptions =>
      _db.collection('prescriptions');
  CollectionReference<Map<String, dynamic>> get _refillRequests =>
      _db.collection('refillRequests');
  CollectionReference<Map<String, dynamic>> get _reminders =>
      _db.collection('reminders');
  CollectionReference<Map<String, dynamic>> get _doseLogs =>
      _db.collection('doseLogs');

  // ---------------------------------------------------------------------------
  // Helpers: who is signed in, demo switch, error messages
  // ---------------------------------------------------------------------------

  /// The signed-in user's uid, or a friendly error when nobody is signed in.
  String _requireUid() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PrescriptionException(
        'Please sign in to see your prescriptions.',
      );
    }
    return user.uid;
  }

  /// Stops patients from doing doctor-only actions (the rules enforce it too).
  Future<String> _requireDoctor() async {
    final uid = _requireUid();
    final role = await _auth.getUserRole(uid);
    if (role != UserRole.doctor) {
      throw const PrescriptionException('Only doctors can do this.');
    }
    return uid;
  }

  /// Home's demo switch (long-press the avatar): Error makes calls fail.
  void _failIfDemoError() {
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PrescriptionException(
        "We couldn't reach the server. Check your connection and try again.",
      );
    }
  }

  String? _cachedUid;
  String? _cachedPatientKey;

  /// The id this patient's documents use: the `patientId` field on
  /// `users/{uid}` when it exists, otherwise the uid. Cached per user.
  Future<String> _patientKey() async {
    final uid = _requireUid();
    if (_cachedUid == uid && _cachedPatientKey != null) {
      return _cachedPatientKey!;
    }

    final doc = await _db.collection('users').doc(uid).get();
    final linked = doc.data()?['patientId'];
    final key = (linked is String && linked.trim().isNotEmpty)
        ? linked.trim()
        : uid;

    _cachedUid = uid;
    _cachedPatientKey = key;
    return key;
  }

  /// Runs a Firestore action and turns Firebase errors into friendly ones.
  Future<T> _guard<T>(String fallback, Future<T> Function() action) async {
    try {
      return await action();
    } on PrescriptionException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('Prescription Firestore error: ${e.code} ${e.message}');
      switch (e.code) {
        case 'permission-denied':
          throw const PrescriptionException(
            'Permission denied. The Firestore rules for prescriptions may not be published yet.',
          );
        case 'unavailable':
          throw const PrescriptionException(
            'No connection. Check your internet and try again.',
          );
        default:
          throw PrescriptionException(fallback);
      }
    }
  }

  String _doseLogId(String patientKey, DateTime day) =>
      '${patientKey}_${dateKey(day)}';

  String _linkedId(String patientKey, String prescriptionId) =>
      '${patientKey}_$prescriptionId';

  List<String> _ids(Object? value) =>
      List<String>.from((value as List?) ?? const <String>[]);

  /// Turns documents into prescriptions, skipping damaged ones.
  List<Prescription> _toPrescriptions(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = <Prescription>[];
    for (final doc in docs) {
      try {
        list.add(prescriptionFromData(doc.id, doc.data()));
      } catch (e) {
        debugPrint('Skipped invalid prescription ${doc.id}: $e');
      }
    }
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Patient: prescriptions, taken doses, refills, reminders
  // ---------------------------------------------------------------------------

  /// The signed-in patient's prescriptions (active and finished).
  ///
  /// Follows the demo switch: Error throws, Empty returns nothing.
  Future<List<Prescription>> fetchPrescriptions() async {
    _failIfDemoError();
    if (DashboardService.instance.scenario == DemoScenario.empty) {
      return const <Prescription>[];
    }

    return _guard(
      "We couldn't load your prescriptions. Check your connection and try again.",
      () async {
        final key = await _patientKey();
        final snap =
            await _prescriptions.where('patientId', isEqualTo: key).get();
        return _toPrescriptions(snap.docs);
      },
    );
  }

  /// Taken-today flag and refill request for one prescription.
  Future<PrescriptionActivity> fetchActivity(String prescriptionId) async {
    _failIfDemoError();

    return _guard(
      "We couldn't load this prescription. Check your connection and try again.",
      () async {
        final key = await _patientKey();
        final log =
            await _doseLogs.doc(_doseLogId(key, DateTime.now())).get();
        final refill =
            await _refillRequests.doc(_linkedId(key, prescriptionId)).get();

        return PrescriptionActivity(
          takenToday:
              _ids(log.data()?['takenIds']).contains(prescriptionId),
          refillRequest:
              refill.exists ? refillRequestFromData(refill.data()!) : null,
        );
      },
    );
  }

  /// Saves (or undoes) "taken today" for a prescription. Home's checklist
  /// reads the same record, so both stay in step.
  Future<void> setTakenToday(String prescriptionId, bool taken) async {
    _failIfDemoError();

    return _guard("We couldn't save that. Please try again.", () async {
      final key = await _patientKey();
      final now = DateTime.now();

      await _doseLogs.doc(_doseLogId(key, now)).set({
        'patientId': key,
        'date': dateKey(now),
        'takenIds': taken
            ? FieldValue.arrayUnion([prescriptionId])
            : FieldValue.arrayRemove([prescriptionId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Sends a refill request. It starts as pending until the doctor answers.
  ///
  /// Throws [PrescriptionException] if the refill is not available yet or a
  /// request is already waiting, so the rule is enforced here and not only
  /// by the disabled button.
  Future<RefillRequest> requestRefill(String prescriptionId) async {
    _failIfDemoError();

    return _guard(
      "We couldn't send your refill request. Please try again.",
      () async {
        final key = await _patientKey();

        final rxDoc = await _prescriptions.doc(prescriptionId).get();
        final data = rxDoc.data();
        if (!rxDoc.exists || data == null) {
          throw const PrescriptionException(
            'We could not find this prescription.',
          );
        }
        final prescription = prescriptionFromData(rxDoc.id, data);

        if (!prescription.isRefillAvailableOn(DateTime.now())) {
          throw const PrescriptionException(
            'This refill is not available yet.',
          );
        }

        final ref = _refillRequests.doc(_linkedId(key, prescriptionId));
        final existing = await ref.get();
        if (existing.exists &&
            refillRequestFromData(existing.data()!).status ==
                RefillStatus.pending) {
          throw const PrescriptionException(
            'You already have a refill request waiting for review.',
          );
        }

        await ref.set({
          'prescriptionId': prescriptionId,
          'patientId': key,
          'doctorId': data['doctorId'],
          'status': RefillStatus.pending.name,
          'requestedAt': FieldValue.serverTimestamp(),
          'answeredAt': null,
        });

        return RefillRequest(
          prescriptionId: prescriptionId,
          requestedAt: DateTime.now(),
        );
      },
    );
  }

  /// The saved reminder for a prescription, or null if there is none.
  /// Damaged saved data is treated as "no reminder" instead of crashing.
  Future<ReminderSetting?> fetchReminder(String prescriptionId) async {
    _failIfDemoError();

    return _guard(
      "We couldn't load your reminder. Check your connection and try again.",
      () async {
        final key = await _patientKey();
        final doc =
            await _reminders.doc(_linkedId(key, prescriptionId)).get();

        final raw = doc.data()?['reminder'];
        if (raw is! Map) return null;

        try {
          return ReminderSetting.fromJson(Map<String, dynamic>.from(raw));
        } catch (_) {
          return null;
        }
      },
    );
  }

  /// Saves the reminder (replaces any earlier one for the same prescription).
  ///
  /// NOTE: this only stores the settings. Real phone notifications need a
  /// package such as flutter_local_notifications (not added yet).
  Future<void> saveReminder(ReminderSetting reminder) async {
    _failIfDemoError();

    return _guard("We couldn't save your reminder. Please try again.", () async {
      final key = await _patientKey();

      await _reminders.doc(_linkedId(key, reminder.prescriptionId)).set({
        'patientId': key,
        'prescriptionId': reminder.prescriptionId,
        'reminder': reminder.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// The days the signed-in patient marked one prescription as taken.
  Future<TakenHistory> fetchTakenHistory(String prescriptionId) async {
    _failIfDemoError();

    return _guard(
      "We couldn't load the doses taken. Check your connection and try again.",
      () async {
        final key = await _patientKey();

        final rxDoc = await _prescriptions.doc(prescriptionId).get();
        final data = rxDoc.data();
        if (!rxDoc.exists || data == null) {
          throw const PrescriptionException(
            'We could not find this prescription.',
          );
        }

        final prescription = prescriptionFromData(rxDoc.id, data);
        final history = await _historyFor(key, [prescription]);
        return history[prescriptionId] ?? const TakenHistory([]);
      },
    );
  }

  /// The patient's medicines for today, for Home's checklist.
  ///
  /// One item per active prescription. The item id is the prescription id,
  /// the same id "Mark as Taken" saves, so Home and Prescriptions agree.
  Future<List<MedicationDose>> fetchTodayDoses() async {
    return _guard(
      "We couldn't load today's medicines. Check your connection and try again.",
      () async {
        final key = await _patientKey();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final snap =
            await _prescriptions.where('patientId', isEqualTo: key).get();
        final log = await _doseLogs.doc(_doseLogId(key, today)).get();
        final taken = _ids(log.data()?['takenIds']).toSet();

        final doses = <MedicationDose>[];
        for (final doc in snap.docs) {
          try {
            final p = prescriptionFromData(doc.id, doc.data());
            if (!p.isActiveOn(today) || p.startDate.isAfter(today)) continue;

            final times = (doc.data()['timesPerDay'] as num?)?.toInt() ?? 1;
            doses.add(
              MedicationDose(
                id: p.id,
                name: p.medicineName,
                dosage: p.strength,
                time: '${times}x a day',
                taken: taken.contains(p.id),
              ),
            );
          } catch (e) {
            debugPrint('Skipped invalid prescription ${doc.id}: $e');
          }
        }
        doses.sort((a, b) => a.name.compareTo(b.name));
        return doses;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Doctor: used by the Patients tab (PatientsService calls these)
  // ---------------------------------------------------------------------------

  /// The name written on prescriptions, e.g. "Dr. Maria Santos".
  String _doctorName() {
    final name = _auth.currentUser?.displayName?.trim() ?? '';
    if (name.isEmpty) return 'Doctor';
    return name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';
  }

  /// Every prescription written for [patientId], newest first.
  Future<List<DoctorPrescription>> fetchDoctorPrescriptions(
    String patientId,
  ) async {
    return _guard(
      "We couldn't load these prescriptions. Check your connection and try again.",
      () async {
        await _requireDoctor();
        final snap =
            await _prescriptions.where('patientId', isEqualTo: patientId).get();

        final list = <DoctorPrescription>[];
        for (final doc in snap.docs) {
          try {
            list.add(doctorPrescriptionFromData(doc.id, doc.data()));
          } catch (e) {
            debugPrint('Skipped invalid prescription ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.startDate.compareTo(a.startDate));
        return list;
      },
    );
  }

  /// Saves a new prescription for [patientId] (Add Prescription > Save).
  /// The patient sees it in their list the next time they open it.
  Future<void> addPrescription(
    String patientId,
    DoctorPrescription prescription,
  ) async {
    return _guard(
      "We couldn't save this prescription. Check your connection and try again.",
      () async {
        final doctorId = await _requireDoctor();

        await _prescriptions.doc(prescription.id).set({
          ...doctorPrescriptionToData(
            prescription,
            patientId: patientId,
            doctorId: doctorId,
            doctorName: _doctorName(),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  /// The patient's refill requests, keyed by prescription id.
  Future<Map<String, RefillRequest>> fetchRefillRequestsForPatient(
    String patientId,
  ) async {
    return _guard(
      "We couldn't load the refill requests. Check your connection and try again.",
      () async {
        await _requireDoctor();
        final snap =
            await _refillRequests.where('patientId', isEqualTo: patientId).get();

        return {
          for (final doc in snap.docs)
            (doc.data()['prescriptionId'] as String? ?? ''):
                refillRequestFromData(doc.data()),
        };
      },
    );
  }

  /// The doctor answers a refill request: approved or declined.
  ///
  /// Only a pending request can be answered. A declined request lets the
  /// patient send a new one; an approved one stays approved.
  Future<RefillRequest> respondToRefill({
    required String patientId,
    required String prescriptionId,
    required RefillStatus answer,
  }) async {
    if (answer == RefillStatus.pending) {
      throw ArgumentError('An answer must be approved or declined.');
    }

    return _guard("We couldn't send your answer. Please try again.", () async {
      await _requireDoctor();

      final ref = _refillRequests.doc(_linkedId(patientId, prescriptionId));
      final doc = await ref.get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        throw const PrescriptionException(
          'There is no refill request to answer.',
        );
      }

      final current = refillRequestFromData(data);
      if (current.status != RefillStatus.pending) {
        throw const PrescriptionException('This request was already answered.');
      }

      await ref.update({
        'status': answer.name,
        'answeredAt': FieldValue.serverTimestamp(),
      });

      return RefillRequest(
        prescriptionId: prescriptionId,
        requestedAt: current.requestedAt,
        status: answer,
      );
    });
  }

  /// The days each of the patient's prescriptions were marked as taken,
  /// keyed by prescription id (so the doctor sees the patient's history).
  Future<Map<String, TakenHistory>> fetchTakenHistoryForPatient(
    String patientId,
  ) async {
    return _guard(
      "We couldn't load the doses taken. Check your connection and try again.",
      () async {
        await _requireDoctor();
        final snap =
            await _prescriptions.where('patientId', isEqualTo: patientId).get();
        return _historyFor(patientId, _toPrescriptions(snap.docs));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Shared: taken history
  // ---------------------------------------------------------------------------

  /// Counts, for each of [prescriptions], the days it was marked as taken.
  /// Reads one small document per day, and keeps only days inside each
  /// prescription's course (so "X of Y days" never has X bigger than Y).
  Future<Map<String, TakenHistory>> _historyFor(
    String patientKey,
    List<Prescription> prescriptions,
  ) async {
    final byId = {for (final p in prescriptions) p.id: p};
    final snap = await _doseLogs.where('patientId', isEqualTo: patientKey).get();

    final daysById = <String, List<DateTime>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final parsed = DateTime.tryParse((data['date'] as String?) ?? '');
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);

      for (final id in _ids(data['takenIds'])) {
        final p = byId[id];
        if (p == null) continue;

        final start =
            DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        if (day.isBefore(start) || day.isAfter(p.lastDay)) continue;

        daysById.putIfAbsent(id, () => <DateTime>[]).add(day);
      }
    }

    return {
      for (final entry in daysById.entries)
        entry.key: TakenHistory(
          entry.value..sort((a, b) => b.compareTo(a)),
        ),
    };
  }
}
