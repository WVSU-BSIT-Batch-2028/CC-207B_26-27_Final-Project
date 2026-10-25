import '../models/appointment_status.dart';
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
          appointments: [],
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
          nextUp: '1:30 PM · Lab Result Review',
          appointments: [
            DoctorAppointment(
              id: 'a1',
              time: '9:00 AM',
              patientName: 'Ana Dela Cruz',
              reason: 'General Consultation',
              isVideo: false,
              status: AppointmentStatus.confirmed,
            ),
            DoctorAppointment(
              id: 'a2',
              time: '10:30 AM',
              patientName: 'Paolo Mendoza',
              reason: 'Follow-up',
              isVideo: true,
              status: AppointmentStatus.confirmed,
            ),
            DoctorAppointment(
              id: 'a3',
              time: '1:30 PM',
              patientName: 'Mark Villanueva',
              reason: 'Lab Result Review',
              isVideo: false,
              status: AppointmentStatus.pending,
            ),
            DoctorAppointment(
              id: 'a4',
              time: '3:00 PM',
              patientName: 'Liza Ramos',
              reason: 'General Consultation',
              isVideo: false,
              status: AppointmentStatus.cancelled,
            ),
          ],
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
