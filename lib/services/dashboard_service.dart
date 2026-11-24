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

class DashboardException implements Exception {
  const DashboardException(this.message);
  final String message;
}

/// Scenarios you can trigger from the Home screen (long-press the avatar)
/// to demo the loading / empty / error states during the presentation.
enum DemoScenario { normal, empty, error }

/// Loads the data for the patient Home screen.
///
/// - Next appointment: the patient's own appointments (AppointmentService,
///   Firestore `appointments`).
/// - Today's medicines: active prescriptions (PrescriptionService).
/// - Vitals: a 7-day SAMPLE history (labelled "Sample" in the app) plus the
///   readings the patient adds. The patient's own readings are saved in
///   Firestore `vitalReadings`, so the doctor sees them (never the samples).
///   Without Firebase (START_ROUTE bypass) they are kept on the device.
class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  /// The demo switch (long-press the avatar on Home). Every service reads it.
  DemoScenario scenario = DemoScenario.normal;

  static const String _vitalKeyPrefix = 'vital_entries_';

  /// Loads everything Home shows: next appointment, vitals and today's
  /// medicines. Follows the demo switch: Error throws, Empty returns nothing.
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

  /// Saves whether a dose was taken today.
  ///
  /// A dose is one of the patient's prescriptions, so this is saved by
  /// PrescriptionService (Firestore). The Prescription screens save to the
  /// same record, so "Mark as Taken" in either place updates both.
  Future<void> setDoseTaken(String doseId, bool taken) =>
      PrescriptionService.instance.setTakenToday(doseId, taken);

  /// The signed-in user's uid, or null without Firebase / when signed out.
  String? get _uid =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  /// Saves a reading the patient entered themselves.
  ///
  /// Signed in: one document in `vitalReadings` (patientId, type, value,
  /// secondary, date). The rules allow it because patientId is the uid.
  /// Throws [DashboardException] if Firestore refuses or is unreachable.
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

    // No Firebase (development bypass): keep it on this device.
    // Stored as "milliseconds|value|secondary" text, one entry per reading.
    final prefs = await SharedPreferences.getInstance();
    final key = '$_vitalKeyPrefix${type.name}';
    final entries = List<String>.from(prefs.getStringList(key) ?? const <String>[]);
    entries.add('${reading.date.millisecondsSinceEpoch}|${reading.value}|${reading.secondary ?? ''}');
    await prefs.setStringList(key, entries);
  }

  /// The patient's own readings from Firestore, grouped by type (one query
  /// for all four vitals). Empty if signed out or the query fails, so Home
  /// still opens with the sample history.
  Future<Map<VitalType, List<VitalReading>>> _loadCloudReadings() async {
    final uid = _uid;
    if (uid == null) return const {};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vitalReadings')
          .where('patientId', isEqualTo: uid)
          .get();
      final byType = <VitalType, List<VitalReading>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final type = VitalType.values.asNameMap()[data['type']];
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
      return byType;
    } on FirebaseException catch (e) {
      debugPrint('vitalReadings read failed: ${e.code}');
      return const {};
    }
  }

  /// Reads back the patient's own entries for one vital type (device copy).
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

  /// One vital card: a 7-day sample history ending today (marked
  /// "Sample"), then the patient's own readings (Firestore when signed in,
  /// otherwise the copy on this device), oldest first.
  Future<VitalSign> _vital(
    VitalType type,
    String label,
    String unit,
    List<double> values, {
    List<double>? secondary,
    Map<VitalType, List<VitalReading>> cloud = const {},
  }) async {
    final now = DateTime.now();
    final sample = <VitalReading>[
      for (var i = 0; i < values.length; i++)
        VitalReading(
          date: DateTime(now.year, now.month, now.day - (values.length - 1 - i), 8),
          value: values[i],
          secondary: secondary?[i],
        ),
    ];
    final mine = _uid != null
        ? (cloud[type] ?? const <VitalReading>[])
        : await _loadUserReadings(type);
    final all = [...sample, ...mine]..sort((a, b) => a.date.compareTo(b.date));
    return VitalSign(type: type, label: label, unit: unit, readings: all);
  }

  /// Today's medicines come from the patient's active prescriptions.
  /// If they cannot be loaded, Home still opens, with an empty checklist.
  Future<List<MedicationDose>> _loadDoses() async {
    try {
      return await PrescriptionService.instance.fetchTodayDoses();
    } on PrescriptionException catch (e) {
      // Shown in the browser console (F12) to explain an empty checklist.
      debugPrint("Today's medicines not loaded: ${e.message}");
      return const <MedicationDose>[];
    }
  }

  /// The patient's next upcoming appointment that is not cancelled, or null.
  /// If appointments cannot be loaded, Home still opens without the card.
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
    // The three loads do not depend on each other, so run them together.
    final results = await Future.wait<Object?>([
      _loadDoses(),
      _loadNextAppointment(),
      _loadCloudReadings(),
    ]);
    final doses = results[0] as List<MedicationDose>;
    final next = results[1] as Appointment?;
    final cloud = results[2] as Map<VitalType, List<VitalReading>>;

    return DashboardData(
      // Home replaces this with the signed-in user's first name.
      patientFirstName: '',
      nextAppointment: next,
      vitals: [
        await _vital(VitalType.heartRate, 'Heart Rate', 'bpm', [70, 74, 71, 76, 73, 72, 72], cloud: cloud),
        await _vital(
          VitalType.bloodPressure,
          'Blood Pressure',
          'mmHg',
          [118, 121, 119, 124, 120, 122, 120],
          secondary: [76, 80, 78, 82, 79, 81, 80],
          cloud: cloud,
        ),
        await _vital(VitalType.weight, 'Weight', 'kg', [58.9, 58.8, 58.7, 58.6, 58.5, 58.4, 58.4], cloud: cloud),
        await _vital(VitalType.sleep, 'Sleep', 'last night', [7.1, 6.4, 6.8, 5.9, 6.6, 7.0, 6.5], cloud: cloud),
      ],
      doses: doses,
    );
  }
}