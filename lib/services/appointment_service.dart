import '../models/appointment.dart';
import '../models/appointment_status.dart';
import 'dashboard_service.dart';

/// Error returned when appointment data cannot be loaded or managed.
class AppointmentException implements Exception {
  const AppointmentException(this.message);

  final String message;
}

/// Provides shared appointment data to patient and doctor screens.
///
/// This service currently uses in-memory mock data and simulated delays.
/// Its methods are structured so the data source can later be replaced
/// with Firebase, MySQL, or an API.
class AppointmentService {
  AppointmentService._();

  /// Shared service instance used by both patient and doctor modules.
  static final AppointmentService instance = AppointmentService._();

  /// Stores appointments created during the current app session.
  final List<Appointment> _createdAppointments = [];

  /// Keeps sample appointments in memory so doctor updates are not lost
  /// whenever the appointment list is refreshed.
  late final List<Appointment> _sampleAppointments = _buildSampleAppointments();

  /// Retrieves appointments from the shared in-memory lists.
  ///
  /// The demo scenario can simulate normal, empty, and error responses.
  Future<List<Appointment>> fetchAppointments() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const AppointmentException(
          "We couldn't load the appointments. Check your connection and try again.",
        );

      case DemoScenario.empty:
        return List.unmodifiable(_createdAppointments);

      case DemoScenario.normal:
        return List.unmodifiable([
          ..._createdAppointments,
          ..._sampleAppointments,
        ]);
    }
  }

  /// Creates a new appointment submitted by a patient.
  ///
  /// New appointments start as pending until the doctor confirms them.
  Future<Appointment> createAppointment({
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String consultationType,
    required double consultationFee,
    required bool reminderEnabled,
    String patientName = 'Demo Patient',
    String? patientId,
    String? meetingUrl,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

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
      patientName: patientName,
      patientId: patientId,
    );

    _createdAppointments.add(appointment);

    return appointment;
  }

  /// Confirms a pending appointment.
  ///
  /// Only pending appointments can be confirmed.
  Future<Appointment> confirmAppointment(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    if (appointment.status != AppointmentStatus.pending) {
      throw const AppointmentException(
        'Only pending appointments can be confirmed.',
      );
    }

    return _replaceAppointment(
      appointment,
      status: AppointmentStatus.confirmed,
    );
  }

  /// Cancels an appointment that has not already been cancelled.
  Future<Appointment> cancelAppointment(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'This appointment is already cancelled.',
      );
    }

    return _replaceAppointment(
      appointment,
      status: AppointmentStatus.cancelled,
    );
  }

  /// Saves a Google Meet link for a confirmed video appointment.
  ///
  /// The link must use HTTPS and the meet.google.com domain.
  Future<Appointment> updateMeetingUrl({
    required String appointmentId,
    required String meetingUrl,
  }) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    if (!appointment.isVideo) {
      throw const AppointmentException(
        'A meeting link can only be added to a video consultation.',
      );
    }

    if (appointment.status != AppointmentStatus.confirmed) {
      throw const AppointmentException(
        'Confirm the appointment before adding a meeting link.',
      );
    }

    final uri = Uri.tryParse(meetingUrl.trim());

    final isValidMeetUrl = uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'meet.google.com' &&
        uri.pathSegments.isNotEmpty;

    if (!isValidMeetUrl) {
      throw const AppointmentException(
        'Enter a valid Google Meet link starting with https://meet.google.com/.',
      );
    }

    return _replaceAppointment(
      appointment,
      meetingUrl: meetingUrl.trim(),
      updateMeetingUrl: true,
    );
  }

  /// Applies a simulated delay and checks for management errors.
  Future<void> _prepareManagementAction() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't update the appointment. Please try again.",
      );
    }
  }

  /// Finds an appointment in either the sample or patient-created list.
  Appointment _findAppointment(String appointmentId) {
    for (final appointment in [
      ..._createdAppointments,
      ..._sampleAppointments,
    ]) {
      if (appointment.id == appointmentId) {
        return appointment;
      }
    }

    throw const AppointmentException(
      'Appointment not found. Refresh the list and try again.',
    );
  }

  /// Replaces an appointment in the correct list while preserving
  /// information that was not changed.
  Appointment _replaceAppointment(
    Appointment oldAppointment, {
    AppointmentStatus? status,
    String? meetingUrl,
    bool updateMeetingUrl = false,
  }) {
    final updatedAppointment = Appointment(
      id: oldAppointment.id,
      title: oldAppointment.title,
      doctorName: oldAppointment.doctorName,
      specialty: oldAppointment.specialty,
      dateTime: oldAppointment.dateTime,
      location: oldAppointment.location,
      isVideo: oldAppointment.isVideo,
      status: status ?? oldAppointment.status,
      consultationFee: oldAppointment.consultationFee,
      reminderEnabled: oldAppointment.reminderEnabled,
      meetingUrl: updateMeetingUrl ? meetingUrl : oldAppointment.meetingUrl,
      patientName: oldAppointment.patientName,
      patientId: oldAppointment.patientId,
    );

    final createdIndex = _createdAppointments.indexWhere(
      (item) => item.id == oldAppointment.id,
    );

    if (createdIndex != -1) {
      _createdAppointments[createdIndex] = updatedAppointment;
      return updatedAppointment;
    }

    final sampleIndex = _sampleAppointments.indexWhere(
      (item) => item.id == oldAppointment.id,
    );

    if (sampleIndex != -1) {
      _sampleAppointments[sampleIndex] = updatedAppointment;
      return updatedAppointment;
    }

    throw const AppointmentException(
      'Appointment could not be updated. Refresh the list and try again.',
    );
  }

  /// Creates the initial sample appointments for the prototype.
  List<Appointment> _buildSampleAppointments() {
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
        patientName: 'Ana Dela Cruz',
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
        patientName: 'Paolo Mendoza',
      ),
      Appointment(
        id: 'apt-003',
        title: 'Pediatric Consultation',
        doctorName: 'Dr. Ana Reyes',
        specialty: 'Pediatrics',
        dateTime: DateTime(now.year, now.month, now.day + 10, 15, 0),
        location: 'Main Clinic',
        status: AppointmentStatus.cancelled,
        patientName: 'Mark Villanueva',
      ),
      Appointment(
        id: 'apt-004',
        title: 'General Consultation',
        doctorName: 'Dr. Elena Cruz',
        specialty: 'General Practitioner',
        dateTime: DateTime(now.year, now.month, now.day - 5, 9, 0),
        location: 'Main Clinic',
        status: AppointmentStatus.confirmed,
        patientName: 'Liza Ramos',
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
        patientName: 'Paolo Mendoza',
      ),
    ];
  }
}
