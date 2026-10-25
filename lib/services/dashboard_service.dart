import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_format.dart';
import '../models/appointment.dart';
import '../models/dashboard_data.dart';
import '../models/medication_dose.dart';
import '../models/vital_sign.dart';

/// Scenarios you can trigger from the Home screen (long-press the avatar)
/// to demo the loading / empty / error states during the presentation.
enum DemoScenario { normal, empty, error }

class DashboardException implements Exception {
  const DashboardException(this.message);
  final String message;
}

/// Loads the data for the patient Home screen.
///
/// For now this is a MOCK that simulates network latency and returns sample
/// data, so the UI can be built and demoed before the backend exists.
/// When the Firebase / MySQL API is ready, replace the bodies of
/// [fetchDashboard] and [addReading]; the screens do not need to change.
class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  DemoScenario scenario = DemoScenario.normal;

  static const String _takenKeyPrefix = 'taken_doses_';
  static const String _vitalKeyPrefix = 'vital_entries_';

  /// Asynchronous call with simulated latency (shows the loading state).
  Future<DashboardData> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    switch (scenario) {
      case DemoScenario.error:
        throw const DashboardException(
          "We couldn't reach the server. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const DashboardData(
          patientFirstName: 'Jahna',
          nextAppointment: null,
          vitals: [],
          doses: [],
        );
      case DemoScenario.normal:
        return _sample();
    }
  }

  /// Saves whether a dose was taken today (local data persistence).
  Future<void> setDoseTaken(String doseId, bool taken) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_takenKeyPrefix${dateKey(DateTime.now())}';
    final ids = (prefs.getStringList(key) ?? <String>[]).toSet();
    if (taken) {
      ids.add(doseId);
    } else {
      ids.remove(doseId);
    }
    await prefs.setStringList(key, ids.toList());
  }

  /// Saves a reading the patient entered themselves (local persistence).
  /// Stored as "milliseconds|value|secondary" text, one entry per reading.
  Future<void> addReading(VitalType type, VitalReading reading) async {
    await Future<void>.delayed(const Duration(milliseconds: 400)); // simulated network
    final prefs = await SharedPreferences.getInstance();
    final key = '$_vitalKeyPrefix${type.name}';
    final entries = List<String>.from(prefs.getStringList(key) ?? const <String>[]);
    entries.add('${reading.date.millisecondsSinceEpoch}|${reading.value}|${reading.secondary ?? ''}');
    await prefs.setStringList(key, entries);
  }

  Future<Set<String>> _takenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_takenKeyPrefix${dateKey(DateTime.now())}';
    return (prefs.getStringList(key) ?? <String>[]).toSet();
  }

  /// Reads back the patient's own entries for one vital type.
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

  /// Builds a 7-day sample history ending today, then adds the user's entries.
  Future<VitalSign> _vital(
    VitalType type,
    String label,
    String unit,
    List<double> values, {
    List<double>? secondary,
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
    final mine = await _loadUserReadings(type);
    return VitalSign(type: type, label: label, unit: unit, readings: [...sample, ...mine]);
  }

  Future<DashboardData> _sample() async {
    final now = DateTime.now();
    final taken = await _takenToday();

    final doses = <MedicationDose>[
      const MedicationDose(
        id: 'dose-1',
        name: 'Vitamin D3',
        dosage: '1000 IU',
        time: '8:00 AM',
      ),
      const MedicationDose(
        id: 'dose-2',
        name: 'Amoxicillin',
        dosage: '500 mg',
        time: '1:00 PM',
      ),
      const MedicationDose(
        id: 'dose-3',
        name: 'Vitamin C',
        dosage: '500 mg',
        time: '7:00 PM',
      ),
    ];

    return DashboardData(
      patientFirstName: 'Jahna',
      nextAppointment: Appointment(
        id: 'apt-1',
        title: 'General Consultation',
        doctorName: 'Dr. Maria Santos',
        specialty: 'General Practitioner',
        dateTime: DateTime(now.year, now.month, now.day + 3, 10, 0),
        location: 'Main Clinic',
      ),
      vitals: [
        await _vital(VitalType.heartRate, 'Heart Rate', 'bpm', [70, 74, 71, 76, 73, 72, 72]),
        await _vital(
          VitalType.bloodPressure,
          'Blood Pressure',
          'mmHg',
          [118, 121, 119, 124, 120, 122, 120],
          secondary: [76, 80, 78, 82, 79, 81, 80],
        ),
        await _vital(VitalType.weight, 'Weight', 'kg', [58.9, 58.8, 58.7, 58.6, 58.5, 58.4, 58.4]),
        await _vital(VitalType.sleep, 'Sleep', 'last night', [7.1, 6.4, 6.8, 5.9, 6.6, 7.0, 6.5]),
      ],
      doses: [for (final d in doses) d.copyWith(taken: taken.contains(d.id))],
    );
  }
}
