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
/// When the Firebase / MySQL API is ready, replace the body of
/// [fetchDashboard] - the screens do not need to change.
class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  DemoScenario scenario = DemoScenario.normal;

  static const String _takenKeyPrefix = 'taken_doses_';

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

  Future<Set<String>> _takenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_takenKeyPrefix${dateKey(DateTime.now())}';
    return (prefs.getStringList(key) ?? <String>[]).toSet();
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
      vitals: const [
        VitalSign(
          type: VitalType.heartRate,
          label: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          trend: [70, 74, 71, 76, 73, 72, 72],
        ),
        VitalSign(
          type: VitalType.bloodPressure,
          label: 'Blood Pressure',
          value: '120/80',
          unit: 'mmHg',
          trend: [118, 121, 119, 124, 120, 122, 120],
        ),
        VitalSign(
          type: VitalType.weight,
          label: 'Weight',
          value: '58.4',
          unit: 'kg',
          trend: [58.9, 58.8, 58.7, 58.6, 58.5, 58.4, 58.4],
        ),
        VitalSign(
          type: VitalType.sleep,
          label: 'Sleep',
          value: '6h 30m',
          unit: 'avg',
          trend: [7.1, 6.4, 6.8, 5.9, 6.6, 7.0, 6.5],
          status: VitalStatus.watch,
        ),
      ],
      doses: [for (final d in doses) d.copyWith(taken: taken.contains(d.id))],
    );
  }
}
