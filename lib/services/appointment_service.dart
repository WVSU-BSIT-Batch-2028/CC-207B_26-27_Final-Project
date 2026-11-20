import '../models/appointment.dart';
import '../models/appointment_status.dart';
import 'dashboard_service.dart';

/// Error returned when appointment data cannot be loaded or created.
class AppointmentException implements Exception {
  const AppointmentException(this.message);

  final String message;
}

/// Provides appointment data to the patient appointment screens.
///
/// This currently uses mock data and simulated network loading.
/// It can later be connected to Firebase, MySQL, or an API.
class AppointmentService {
  AppointmentService._();

  /// Shared service instance.
  static final AppointmentService instance = AppointmentService._();

  /// Stores appointments created during the current app session.
  final List<Appointment> _createdAppointments = [];

  /// Retrieves the patient's appointments.
  ///
  /// Combines sample appointments with newly created appointments.
  /// The demo scenario can also simulate empty and error responses.
  Future<List<Appointment>> fetchAppointments() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const AppointmentException(
          "We couldn't load your appointments. Check your connection and try again.",
        );

      case DemoScenario.empty:
        return List.unmodifiable(_createdAppointments);

      case DemoScenario.normal:
        return [
          ..._createdAppointments,
          ..._sampleAppointments(),
        ];
    }
  }

  /// Creates and stores a new appointment.
  ///
  /// The appointment starts as pending because the doctor
  /// still needs to confirm the booking request.
  Future<Appointment> createAppointment({
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String consultationType,
    required double consultationFee,
    required bool reminderEnabled,
    String? meetingUrl,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    // Simulate a booking submission error for testing.
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't submit your booking. Please try again.",
      );
    }

    final isVideo = consultationType.toLowerCase().contains('video');

    final appointment = Appointment(
      id: 'apt-${DateTime.now().microsecondsSinceEpoch}',
      title: '$specialty Consultation',
      doctorName: doctorName,
      specialty: specialty,
      dateTime: dateTime,
      location: isVideo ? 'Video Consultation' : 'Main Clinic',
      isVideo: isVideo,
      status: AppointmentStatus.pending,
      consultationFee: consultationFee,
      reminderEnabled: reminderEnabled,
      meetingUrl: meetingUrl,
    );

    _createdAppointments.add(appointment);

    return appointment;
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
