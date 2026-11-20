import '../models/appointment.dart';
import '../models/appointment_status.dart';
import 'dashboard_service.dart';

/// Error returned when appointment data cannot be loaded.
class AppointmentException implements Exception {
  const AppointmentException(this.message);

  final String message;
}

/// Provides appointment data to the patient appointment screens.
///
/// This currently uses mock data and simulated network loading.
/// The service can later be connected to Firebase, MySQL, or an API
/// without requiring major changes to the screen.
class AppointmentService {
  AppointmentService._();

  /// Shared service instance.
  static final AppointmentService instance = AppointmentService._();

  /// Retrieves the patient's appointments.
  ///
  /// Uses the existing Home demo scenarios to demonstrate
  /// normal, empty, and error states.
  Future<List<Appointment>> fetchAppointments() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const AppointmentException(
          "We couldn't load your appointments. Check your connection and try again.",
        );

      case DemoScenario.empty:
        return [];

      case DemoScenario.normal:
        return _sampleAppointments();
    }
  }

  /// Creates sample upcoming and past appointments.
  List<Appointment> _sampleAppointments() {
    final now = DateTime.now();

    return [
      Appointment(
        id: 'apt-001',
        title: 'General Consultation',
        doctorName: 'Dr. Elena Cruz',
        specialty: 'General Practitioner',
        dateTime: DateTime(now.year, now.month, now.day + 3, 10, 0),
        location: 'Main Clinic',
        status: AppointmentStatus.confirmed,
      ),
      Appointment(
        id: 'apt-002',
        title: 'Internal Medicine Consultation',
        doctorName: 'Dr. Juan Dela Cruz',
        specialty: 'Internal Medicine',
        dateTime: DateTime(now.year, now.month, now.day + 7, 13, 0),
        location: 'Video Consultation',
        isVideo: true,
        status: AppointmentStatus.pending,
      ),
      Appointment(
        id: 'apt-003',
        title: 'Pediatric Consultation',
        doctorName: 'Dr. Ana Reyes',
        specialty: 'Pediatrics',
        dateTime: DateTime(now.year, now.month, now.day + 10, 15, 0),
        location: 'Main Clinic',
        status: AppointmentStatus.cancelled,
      ),
      Appointment(
        id: 'apt-004',
        title: 'General Consultation',
        doctorName: 'Dr. Elena Cruz',
        specialty: 'General Practitioner',
        dateTime: DateTime(now.year, now.month, now.day - 5, 9, 0),
        location: 'Main Clinic',
        status: AppointmentStatus.confirmed,
      ),
      Appointment(
        id: 'apt-005',
        title: 'Internal Medicine Consultation',
        doctorName: 'Dr. Juan Dela Cruz',
        specialty: 'Internal Medicine',
        dateTime: DateTime(now.year, now.month, now.day - 12, 14, 0),
        location: 'Video Consultation',
        isVideo: true,
        status: AppointmentStatus.confirmed,
      ),
    ];
  }
}
