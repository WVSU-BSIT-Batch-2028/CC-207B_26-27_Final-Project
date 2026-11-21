
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import 'dashboard_service.dart';

/// Error returned when appointment data cannot be loaded or updated.
class AppointmentException implements Exception {
  /// Creates an appointment exception with a readable message.
  const AppointmentException(this.message);

  /// Message displayed to the user.
  final String message;

  @override
  String toString() => message;
}

/// Provides appointment data and appointment management operations.
///
/// This service currently uses mock data and simulates network delays.
/// Its methods are structured so the data source can later be replaced
/// with Firebase, MySQL, or an API without changing the screens.
class AppointmentService {
  AppointmentService._();

  /// Shared instance of the appointment service.
  static final AppointmentService instance = AppointmentService._();

  /// Stores appointments created through the patient booking flow.
  final List<Appointment> _createdAppointments = [];

  /// Stores sample appointments so status and meeting-link changes
  /// remain available while the application is running.
  late final List<Appointment> _sampleAppointments =
      _buildSampleAppointments();

  /// Retrieves appointments for the patient and doctor views.
  Future<List<Appointment>> fetchAppointments() async {
    await Future<void>.delayed(const Duration(seconds: 1));

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

  /// Creates an appointment from the patient booking flow.
  ///
  /// The consultation fee is received from the selected doctor.
  /// Newly created appointments start with a pending status.
  Future<Appointment> createAppointment({
    required String title,
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String location,
    required bool isVideo,
    required double consultationFee,
    required bool reminderEnabled,
    String patientName = 'Demo Patient',
    String? patientId,
    String? meetingUrl,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't complete your booking. Please try again.",
      );
    }

    final appointment = Appointment(
      id: 'apt-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      patientName: patientName,
      patientId: patientId,
      doctorName: doctorName,
      specialty: specialty,
      dateTime: dateTime,
      location: location,
      isVideo: isVideo,
      status: AppointmentStatus.pending,
      consultationFee: consultationFee,
      reminderEnabled: reminderEnabled,
      meetingUrl: meetingUrl,
    );

    _createdAppointments.insert(0, appointment);

    return appointment;
  }

  /// Confirms an appointment that is currently pending.
  Future<Appointment> confirmAppointment(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    if (appointment.status != AppointmentStatus.pending) {
      throw const AppointmentException(
        'Only pending appointments can be confirmed.',
      );
    }

    final updatedAppointment = _copyWithStatus(
      appointment,
      AppointmentStatus.confirmed,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Cancels an appointment unless it has already been cancelled.
  Future<Appointment> cancelAppointment(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'This appointment has already been cancelled.',
      );
    }

    final updatedAppointment = _copyWithStatus(
      appointment,
      AppointmentStatus.cancelled,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Updates the Google Meet URL of a confirmed video appointment.
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
        'Only confirmed appointments can receive a meeting link.',
      );
    }

    final uri = Uri.tryParse(meetingUrl.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'meet.google.com' ||
        uri.pathSegments.isEmpty) {
      throw const AppointmentException(
        'Enter a valid Google Meet link.',
      );
    }

    final updatedAppointment = _copyWithMeetingUrl(
      appointment,
      meetingUrl.trim(),
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Simulates the delay and error handling of a management request.
  Future<void> _prepareManagementAction() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const AppointmentException(
        "We couldn't update the appointment. Please try again.",
      );
    }
  }

  /// Finds an appointment by its unique ID.
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
      'The appointment could not be found.',
    );
  }

  /// Replaces an existing appointment in the correct in-memory list.
  void _replaceAppointment(Appointment updatedAppointment) {
    final createdIndex = _createdAppointments.indexWhere(
      (appointment) => appointment.id == updatedAppointment.id,
    );

    if (createdIndex != -1) {
      _createdAppointments[createdIndex] = updatedAppointment;
      return;
    }

    final sampleIndex = _sampleAppointments.indexWhere(
      (appointment) => appointment.id == updatedAppointment.id,
    );

    if (sampleIndex != -1) {
      _sampleAppointments[sampleIndex] = updatedAppointment;
    }
  }

  /// Creates a copy of an appointment with an updated status.
  Appointment _copyWithStatus(
    Appointment appointment,
    AppointmentStatus status,
  ) {
    return Appointment(
      id: appointment.id,
      title: appointment.title,
      doctorName: appointment.doctorName,
      specialty: appointment.specialty,
      dateTime: appointment.dateTime,
      location: appointment.location,
      isVideo: appointment.isVideo,
      status: status,
      consultationFee: appointment.consultationFee,
      reminderEnabled: appointment.reminderEnabled,
      meetingUrl: appointment.meetingUrl,
      patientName: appointment.patientName,
      patientId: appointment.patientId,
    );
  }

  /// Creates a copy of an appointment with an updated meeting URL.
  Appointment _copyWithMeetingUrl(
    Appointment appointment,
    String meetingUrl,
  ) {
    return Appointment(
      id: appointment.id,
      title: appointment.title,
      doctorName: appointment.doctorName,
      specialty: appointment.specialty,
      dateTime: appointment.dateTime,
      location: appointment.location,
      isVideo: appointment.isVideo,
      status: appointment.status,
      consultationFee: appointment.consultationFee,
      reminderEnabled: appointment.reminderEnabled,
      meetingUrl: meetingUrl,
      patientName: appointment.patientName,
      patientId: appointment.patientId,
    );
  }

  /// Builds sample appointments for the patient and doctor views.
  ///
  /// Doctor names and fees match BookingDoctorService.
  List<Appointment> _buildSampleAppointments() {
    final now = DateTime.now();

    return [
      Appointment(
        id: 'apt-001',
        title: 'General Consultation',
        patientName: 'Ana Dela Cruz',
        patientId: 'PAT-001',
        doctorName: 'Dr. Elena Cruz',
        specialty: 'General Practitioner',
        dateTime: now.add(const Duration(days: 2)),
        location: 'Health360 Medical Clinic',
        isVideo: false,
        status: AppointmentStatus.confirmed,
        consultationFee: 500,
      ),
      Appointment(
        id: 'apt-002',
        title: 'Internal Medicine Consultation',
        patientName: 'Paolo Mendoza',
        patientId: 'PAT-002',
        doctorName: 'Dr. Andrea Santos',
        specialty: 'Internal Medicine',
        dateTime: now.add(const Duration(days: 3)),
        location: 'Google Meet',
        isVideo: true,
        status: AppointmentStatus.pending,
        consultationFee: 700,
      ),
      Appointment(
        id: 'apt-003',
        title: 'Pediatric Consultation',
        patientName: 'Mark Villanueva',
        patientId: 'PAT-003',
        doctorName: 'Dr. Sofia Villanueva',
        specialty: 'Pediatrician',
        dateTime: now.add(const Duration(days: 4)),
        location: 'Health360 Medical Clinic',
        isVideo: false,
        status: AppointmentStatus.cancelled,
        consultationFee: 650,
      ),
      Appointment(
        id: 'apt-004',
        title: 'General Consultation',
        patientName: 'Liza Ramos',
        patientId: 'PAT-004',
        doctorName: 'Dr. Elena Cruz',
        specialty: 'General Practitioner',
        dateTime: now.subtract(const Duration(days: 5)),
        location: 'Health360 Medical Clinic',
        isVideo: false,
        status: AppointmentStatus.confirmed,
        consultationFee: 500,
      ),
      Appointment(
        id: 'apt-005',
        title: 'Internal Medicine Consultation',
        patientName: 'Paolo Mendoza',
        patientId: 'PAT-002',
        doctorName: 'Dr. Andrea Santos',
        specialty: 'Internal Medicine',
        dateTime: now.subtract(const Duration(days: 2)),
        location: 'Google Meet',
        isVideo: true,
        status: AppointmentStatus.confirmed,
        consultationFee: 700,
      ),
    ];
  }
}
