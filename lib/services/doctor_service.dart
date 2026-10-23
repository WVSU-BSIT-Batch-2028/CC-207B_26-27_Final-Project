import '../models/doctor_dashboard_data.dart';
import 'dashboard_service.dart';

/// MOCK data source for the doctor Home and Dashboard.
/// Uses the same demo scenario switch as the patient Home
/// (long-press the avatar) so loading / empty / error can be demoed.
class DoctorService {
  DoctorService._();
  static final DoctorService instance = DoctorService._();

  static const String specialty = 'General Practitioner';

  Future<DoctorDashboardData> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const DashboardException(
          "We couldn't load your schedule. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const DoctorDashboardData(
          doctorShortName: 'Dr. Santos',
          specialty: specialty,
          todayAppointments: 0,
          patients: 0,
          prescriptions: 0,
          labResults: 0,
          nextUp: null,
          activities: [],
        );
      case DemoScenario.normal:
        return const DoctorDashboardData(
          doctorShortName: 'Dr. Santos',
          specialty: specialty,
          todayAppointments: 8,
          patients: 12,
          prescriptions: 5,
          labResults: 3,
          nextUp: '2:30 PM · General Consultation',
          activities: [
            ActivityItem(
              type: ActivityType.labResult,
              title: 'New lab result available',
              subtitle: 'Patient: Mark Villanueva',
              time: '10:30 AM',
            ),
            ActivityItem(
              type: ActivityType.prescription,
              title: 'Prescription updated',
              subtitle: 'Patient: Ana Dela Cruz',
              time: '9:45 AM',
            ),
            ActivityItem(
              type: ActivityType.message,
              title: 'New message from patient',
              subtitle: 'Patient: Paolo Mendoza',
              time: '8:30 AM',
            ),
          ],
        );
    }
  }
}
