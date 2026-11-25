import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/dashboard_data.dart';
import '../models/medication_dose.dart';
import '../models/vital_sign.dart';
import 'appointment_service.dart';
import 'prescription_service.dart';

/// A Home loading or saving error with a message for the user.
class DashboardException implements Exception {
  const DashboardException(this.message);
  final String message;
}

/// Demo states for the presentation (long-press the avatar on Home).
enum DemoScenario { normal, empty, error }

/// Loads the patient Home: next appointment, today's medicines and vitals
/// (`vitalReadings`, also seen by the doctor). Without Firebase, readings
/// are kept on the device.
class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  /// The demo switch. Every service reads it.
  DemoScenario scenario = DemoScenario.normal;

  static const String _vitalKeyPrefix = 'vital_entries_';

  /// From this day patients enter their own vitals. Older accounts get a
  /// one-time history; newer accounts start empty.
  static final DateTime vitalsStartDay = DateTime(2026, 11, 25);

  /// The one-time history: one reading a day for the 7 days before
  /// [vitalsStartDay], oldest first.
  static const Map<VitalType, ({List<double> values, List<double>? secondary})>
      _history = {
    VitalType.heartRate: (values: [70, 74, 71, 76, 73, 72, 72], secondary: null),
    VitalType.bloodPressure: (
      values: [118, 121, 119, 124, 120, 122, 120],
      secondary: [76, 80, 78, 82, 79, 81, 80],
    ),
    VitalType.weight: (values: [58.9, 58.8, 58.7, 58.6, 58.5, 58.4, 58.4], secondary: null),
    VitalType.sleep: (values: [7.1, 6.4, 6.8, 5.9, 6.6, 7.0, 6.5], secondary: null),
  };

  /// Everything Home shows. Error demo throws; Empty demo returns nothing.
  Future<DashboardData> fetchDashboard() async {
    switch (scenario) {
      case DemoScenario.error:
        throw const DashboardException(
          "We couldn't reach the server. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const DashboardData(
          patientFirstName: '',
          nextAppointment: null,
          vitals: [],
          doses: [],
        );
      case DemoScenario.normal:
        return _load();
    }
  }

  /// Saves whether a dose was taken today (same record as Prescriptions).
  Future<void> setDoseTaken(String doseId, bool taken) =>
      PrescriptionService.instance.setTakenToday(doseId, taken);

  /// The signed-in user's uid, or null without Firebase / when signed out.
  String? get _uid =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  /// Saves a reading the patient entered (Firestore when signed in).
  Future<void> addReading(VitalType type, VitalReading reading) async {
    final uid = _uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('vitalReadings').add({
          'patientId': uid,
          'type': type.name,
          'value': reading.value,
          'secondary': reading.secondary,
          'date': Timestamp.fromDate(reading.date),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      } on FirebaseException catch (e) {
        debugPrint('vitalReadings write failed: ${e.code}');
        throw const DashboardException(
          "We couldn't save your reading. Check your connection and try again.",
        );
      }
    }

    // No Firebase: keep it on this device as "millis|value|secondary".
    final prefs = await SharedPreferences.getInstance();
    final key = '$_vitalKeyPrefix${type.name}';
    final entries = List<String>.from(prefs.getStringList(key) ?? const <String>[]);
    entries.add('${reading.date.millisecondsSinceEpoch}|${reading.value}|${reading.secondary ?? ''}');
    await prefs.setStringList(key, entries);
  }

  /// The patient's readings from Firestore, grouped by type (one query).
  /// Empty when signed out or on error, so Home still opens.
  Future<Map<VitalType, List<VitalReading>>> _loadCloudReadings() async {
    final uid = _uid;
    if (uid == null) return const {};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vitalReadings')
          .where('patientId', isEqualTo: uid)
          .get();
      final byType = <VitalType, List<VitalReading>>{};
      final seeded = <VitalType>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final type = VitalType.values.asNameMap()[data['type']];
        if (type != null && data['seeded'] == true) seeded.add(type);
        final date = data['date'];
        final value = data['value'];
        if (type == null || date is! Timestamp || value is! num) continue;
        final secondary = data['secondary'];
        byType.putIfAbsent(type, () => []).add(VitalReading(
              date: date.toDate(),
              value: value.toDouble(),
              secondary: secondary is num ? secondary.toDouble() : null,
              source: ReadingSource.you,
            ));
      }
      for (final list in byType.values) {
        list.sort((a, b) => a.date.compareTo(b.date));
      }
      _seededTypes = seeded;
      return byType;
    } on FirebaseException catch (e) {
      debugPrint('vitalReadings read failed: ${e.code}');
      // Unknown state, so do not write the history this time.
      _seededTypes = VitalType.values.toSet();
      return const {};
    }
  }

  /// The patient's readings saved on this device for one vital type.
  Future<List<VitalReading>> _loadUserReadings(VitalType type) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('$_vitalKeyPrefix${type.name}') ?? const <String>[];
    final readings = <VitalReading>[];
    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length != 3) continue;
      final millis = int.tryParse(parts[0]);
      final value = double.tryParse(parts[1]);
      if (millis == null || value == null) continue;
      readings.add(VitalReading(
        date: DateTime.fromMillisecondsSinceEpoch(millis),
        value: value,
        secondary: double.tryParse(parts[2]),
        source: ReadingSource.you,
      ));
    }
    return readings;
  }

  /// One vital card with the patient's readings, oldest first.
  Future<VitalSign> _vital(
    VitalType type,
    String label,
    String unit, {
    Map<VitalType, List<VitalReading>> cloud = const {},
  }) async {
    final mine = _uid != null
        ? (cloud[type] ?? const <VitalReading>[])
        : await _loadUserReadings(type);
    final all = [...mine]..sort((a, b) => a.date.compareTo(b.date));
    return VitalSign(type: type, label: label, unit: unit, readings: all);
  }

  /// Older accounts only: writes the 7-day history for each vital that
  /// does not have it yet. Fixed document ids (uid_type_date) prevent
  /// duplicates; if writing fails, Home shows what was already there.
  Future<Map<VitalType, List<VitalReading>>> _withHistory(
    Map<VitalType, List<VitalReading>> cloud,
  ) async {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    final created = user?.metadata.creationTime;
    if (user == null || created == null || !created.toLocal().isBefore(vitalsStartDay)) {
      return cloud;
    }

    final missing = [
      for (final type in _history.keys)
        if (!_seededTypes.contains(type)) type,
    ];
    if (missing.isEmpty) return cloud;

    final result = {for (final e in cloud.entries) e.key: [...e.value]};
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    for (final type in missing) {
      final h = _history[type]!;
      for (var i = 0; i < h.values.length; i++) {
        final day = DateTime(
          vitalsStartDay.year,
          vitalsStartDay.month,
          vitalsStartDay.day - (h.values.length - i),
          8,
        );
        final id = '${user.uid}_${type.name}_${day.year}${_two(day.month)}${_two(day.day)}';
        batch.set(db.collection('vitalReadings').doc(id), {
          'patientId': user.uid,
          'type': type.name,
          'value': h.values[i],
          'secondary': h.secondary?[i],
          'date': Timestamp.fromDate(day),
          'createdAt': FieldValue.serverTimestamp(),
          'seeded': true, // marks the one-time history in the database only
        });
        result.putIfAbsent(type, () => []).add(VitalReading(
              date: day,
              value: h.values[i],
              secondary: h.secondary?[i],
              source: ReadingSource.you,
            ));
      }
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // Already written by another load, or offline: keep what was loaded.
      debugPrint('Vitals history not written: ${e.code}');
      return cloud;
    }
    for (final list in result.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
    return result;
  }

  /// Vitals that already have the history (set by [_loadCloudReadings]).
  Set<VitalType> _seededTypes = const {};

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Today's medicines; empty checklist if they cannot be loaded.
  Future<List<MedicationDose>> _loadDoses() async {
    try {
      return await PrescriptionService.instance.fetchTodayDoses();
    } on PrescriptionException catch (e) {
      // Shown in the console (F12) to explain an empty checklist.
      debugPrint("Today's medicines not loaded: ${e.message}");
      return const <MedicationDose>[];
    }
  }

  /// Next upcoming appointment that is not cancelled, or null.
  Future<Appointment?> _loadNextAppointment() async {
    if (_uid == null) return null;
    try {
      final now = DateTime.now();
      final upcoming = (await AppointmentService.instance.fetchAppointments())
          .where((a) =>
              a.dateTime.isAfter(now) &&
              (a.status == AppointmentStatus.confirmed ||
                  a.status == AppointmentStatus.pending))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return upcoming.isEmpty ? null : upcoming.first;
    } on AppointmentException {
      return null;
    }
  }

  Future<DashboardData> _load() async {
    // Independent loads, so run them together.
    final results = await Future.wait<Object?>([
      _loadDoses(),
      _loadNextAppointment(),
      _loadCloudReadings(),
    ]);
    final doses = results[0] as List<MedicationDose>;
    final next = results[1] as Appointment?;
    final cloud = await _withHistory(results[2] as Map<VitalType, List<VitalReading>>);

    return DashboardData(
      // Home replaces this with the signed-in user's first name.
      patientFirstName: '',
      nextAppointment: next,
      vitals: [
        await _vital(VitalType.heartRate, 'Heart Rate', 'bpm', cloud: cloud),
        await _vital(VitalType.bloodPressure, 'Blood Pressure', 'mmHg', cloud: cloud),
        await _vital(VitalType.weight, 'Weight', 'kg', cloud: cloud),
        await _vital(VitalType.sleep, 'Sleep', 'last night', cloud: cloud),
      ],
      doses: doses,
    );
  }
}