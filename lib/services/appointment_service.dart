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

  /// Maximum time allowed for a patient to request booking changes.
  static const Duration changeRequestWindow = Duration(hours: 24);

  /// Maximum number of edit requests a patient can submit per appointment.
  static const int maximumEditRequests = 2;

  /// Stores appointments created through the patient booking flow.
  final List<Appointment> _createdAppointments = [];

  /// Stores sample appointments so changes remain available while running.
  late final List<Appointment> _sampleAppointments = _buildSampleAppointments();

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
  /// The original booking timestamp is saved to enforce the 24-hour
  /// change request window. New appointments begin with zero edit requests.
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

    if (!dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'Please select a future appointment date and time.',
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
      bookedAt: DateTime.now(),
      editRequestCount: 0,
    );

    _createdAppointments.insert(0, appointment);

    return appointment;
  }

  /// Confirms an appointment that is currently pending and not yet past.
  Future<Appointment> confirmAppointment(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensureUpcoming(appointment);

    if (appointment.status != AppointmentStatus.pending) {
      throw const AppointmentException(
        'Only pending appointments can be confirmed.',
      );
    }

    final updatedAppointment = _copyAppointment(
      appointment,
      status: AppointmentStatus.confirmed,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Cancels an appointment immediately without doctor approval.
  ///
  /// This method is intended for doctor-side cancellation.
  /// Patients should use [cancelPatientAppointment] so the 24-hour
  /// booking window is enforced.
  Future<Appointment> cancelAppointment(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensureUpcoming(appointment);

    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'This appointment has already been cancelled.',
      );
    }

    final updatedAppointment = _copyAppointment(
      appointment,
      status: AppointmentStatus.cancelled,
      clearChangeRequest: true,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Allows a patient to cancel an upcoming appointment immediately.
  ///
  /// Cancellation does not consume an edit request. The existing
  /// 24-hour booking window is still enforced.
  Future<Appointment> cancelPatientAppointment(
    String appointmentId,
  ) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensureWithinChangeRequestWindow(appointment);
    _ensureUpcoming(appointment);

    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'This appointment has already been cancelled.',
      );
    }

    final updatedAppointment = _copyAppointment(
      appointment,
      status: AppointmentStatus.cancelled,
      clearChangeRequest: true,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Submits a patient's request to change all booking details.
  ///
  /// Every submitted request consumes one of the two allowed edit requests,
  /// even if the doctor later rejects it.
  ///
  /// The original appointment remains unchanged until a doctor approves
  /// the request.
  Future<Appointment> requestAppointmentChange({
    required String appointmentId,
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String location,
    required bool isVideo,
    required double consultationFee,
    required bool reminderEnabled,
  }) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensureWithinChangeRequestWindow(appointment);
    _ensureUpcoming(appointment);

    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'A cancelled appointment cannot be edited.',
      );
    }

    if (appointment.changeRequest?.status == ChangeRequestStatus.pending) {
      throw const AppointmentException(
        'You already have a change request waiting for doctor approval.',
      );
    }

    if (appointment.editRequestCount >= maximumEditRequests) {
      throw const AppointmentException(
        'You have used both allowed edit requests for this appointment.',
      );
    }

    if (!dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'The requested appointment date and time must be in the future.',
      );
    }

    final request = AppointmentChangeRequest(
      doctorName: doctorName,
      specialty: specialty,
      dateTime: dateTime,
      location: location,
      isVideo: isVideo,
      consultationFee: consultationFee,
      reminderEnabled: reminderEnabled,
      requestedAt: DateTime.now(),
    );

    final updatedAppointment = _copyAppointment(
      appointment,
      changeRequest: request,
      editRequestCount: appointment.editRequestCount + 1,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Approves a patient's pending change request.
  ///
  /// The requested booking details replace the original details only
  /// after this method is called successfully. The edit request count
  /// and original booking timestamp remain unchanged.
  Future<Appointment> approveAppointmentChange(
    String appointmentId,
  ) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);
    final request = appointment.changeRequest;

    _ensureUpcoming(appointment);

    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'A cancelled appointment cannot be changed.',
      );
    }

    if (request == null || request.status != ChangeRequestStatus.pending) {
      throw const AppointmentException(
        'There is no pending change request to approve.',
      );
    }

    if (!request.dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'The requested appointment date and time has already passed.',
      );
    }

    final approvedRequest = _copyChangeRequest(
      request,
      status: ChangeRequestStatus.approved,
    );

    final updatedAppointment = _copyAppointment(
      appointment,
      title: 'Consultation with ${request.doctorName}',
      doctorName: request.doctorName,
      specialty: request.specialty,
      dateTime: request.dateTime,
      location: request.location,
      isVideo: request.isVideo,
      consultationFee: request.consultationFee,
      reminderEnabled: request.reminderEnabled,
      clearMeetingUrl: true,
      changeRequest: approvedRequest,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Rejects a patient's pending change request.
  ///
  /// The original appointment details and edit request count remain
  /// unchanged. The rejected request is retained for patient display.
  Future<Appointment> rejectAppointmentChange(
    String appointmentId,
  ) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);
    final request = appointment.changeRequest;

    _ensureUpcoming(appointment);

    if (request == null || request.status != ChangeRequestStatus.pending) {
      throw const AppointmentException(
        'There is no pending change request to reject.',
      );
    }

    final rejectedRequest = _copyChangeRequest(
      request,
      status: ChangeRequestStatus.rejected,
    );

    final updatedAppointment = _copyAppointment(
      appointment,
      changeRequest: rejectedRequest,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Marks a past appointment as completed.
  Future<Appointment> markAppointmentDone(String appointmentId) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensurePast(appointment);
    _ensureNotCancelled(appointment);

    final updatedAppointment = _copyAppointment(
      appointment,
      status: AppointmentStatus.done,
      outcome: AppointmentOutcome.done,
      clearChangeRequest: true,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Marks a past appointment as a no-show.
  Future<Appointment> markAppointmentNoShow(
    String appointmentId,
  ) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensurePast(appointment);
    _ensureNotCancelled(appointment);

    final updatedAppointment = _copyAppointment(
      appointment,
      status: AppointmentStatus.noShow,
      outcome: AppointmentOutcome.noShow,
      clearChangeRequest: true,
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Updates the Google Meet URL of an upcoming confirmed video appointment.
  Future<Appointment> updateMeetingUrl({
    required String appointmentId,
    required String meetingUrl,
  }) async {
    await _prepareManagementAction();

    final appointment = _findAppointment(appointmentId);

    _ensureUpcoming(appointment);

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

    if (appointment.changeRequest?.status == ChangeRequestStatus.pending) {
      throw const AppointmentException(
        'Resolve the pending change request before updating the meeting link.',
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

    final updatedAppointment = _copyAppointment(
      appointment,
      meetingUrl: meetingUrl.trim(),
    );

    _replaceAppointment(updatedAppointment);

    return updatedAppointment;
  }

  /// Checks whether a patient is still within the original 24-hour window.
  ///
  /// This check does not change or reset the original booking timestamp.
  void _ensureWithinChangeRequestWindow(Appointment appointment) {
    final bookedAt = appointment.bookedAt;

    if (bookedAt == null) {
      throw const AppointmentException(
        'The original booking time is unavailable. This appointment cannot be edited.',
      );
    }

    final elapsed = DateTime.now().difference(bookedAt);

    if (elapsed.isNegative || elapsed > changeRequestWindow) {
      throw const AppointmentException(
        'The 24-hour period for changing or cancelling this appointment has expired.',
      );
    }
  }

  /// Prevents changes to appointments whose scheduled time has passed.
  void _ensureUpcoming(Appointment appointment) {
    if (!appointment.dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'Past appointments cannot be changed.',
      );
    }

    if (appointment.outcome != AppointmentOutcome.none) {
      throw const AppointmentException(
        'This appointment already has a recorded outcome and cannot be changed.',
      );
    }
  }

  /// Ensures that an appointment has already passed.
  void _ensurePast(Appointment appointment) {
    if (appointment.dateTime.isAfter(DateTime.now())) {
      throw const AppointmentException(
        'Only past appointments can be marked as Done or No-show.',
      );
    }
  }

  /// Prevents outcome changes to cancelled appointments.
  void _ensureNotCancelled(Appointment appointment) {
    if (appointment.status == AppointmentStatus.cancelled) {
      throw const AppointmentException(
        'Cancelled appointments cannot receive an outcome.',
      );
    }
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

  /// Creates a copy of an appointment with selected fields updated.
  ///
  /// The clear flags allow nullable fields to be explicitly reset to null.
  Appointment _copyAppointment(
    Appointment appointment, {
    String? title,
    String? doctorName,
    String? specialty,
    DateTime? dateTime,
    String? location,
    bool? isVideo,
    AppointmentStatus? status,
    double? consultationFee,
    bool? reminderEnabled,
    String? meetingUrl,
    AppointmentOutcome? outcome,
    AppointmentChangeRequest? changeRequest,
    int? editRequestCount,
    bool clearMeetingUrl = false,
    bool clearChangeRequest = false,
  }) {
    return Appointment(
      id: appointment.id,
      title: title ?? appointment.title,
      doctorName: doctorName ?? appointment.doctorName,
      specialty: specialty ?? appointment.specialty,
      dateTime: dateTime ?? appointment.dateTime,
      location: location ?? appointment.location,
      isVideo: isVideo ?? appointment.isVideo,
      status: status ?? appointment.status,
      consultationFee: consultationFee ?? appointment.consultationFee,
      reminderEnabled: reminderEnabled ?? appointment.reminderEnabled,
      meetingUrl: clearMeetingUrl ? null : meetingUrl ?? appointment.meetingUrl,
      patientName: appointment.patientName,
      patientId: appointment.patientId,
      bookedAt: appointment.bookedAt,
      outcome: outcome ?? appointment.outcome,
      changeRequest: clearChangeRequest
          ? null
          : changeRequest ?? appointment.changeRequest,
      editRequestCount: editRequestCount ?? appointment.editRequestCount,
    );
  }

  /// Creates a copy of a change request with an updated review status.
  AppointmentChangeRequest _copyChangeRequest(
    AppointmentChangeRequest request, {
    required ChangeRequestStatus status,
  }) {
    return AppointmentChangeRequest(
      doctorName: request.doctorName,
      specialty: request.specialty,
      dateTime: request.dateTime,
      location: request.location,
      isVideo: request.isVideo,
      consultationFee: request.consultationFee,
      reminderEnabled: request.reminderEnabled,
      requestedAt: request.requestedAt,
      status: status,
    );
  }

  /// Builds sample appointments for the patient and doctor views.
  ///
  /// Booking timestamps are included to demonstrate the 24-hour rule.
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
        bookedAt: now.subtract(const Duration(hours: 2)),
        editRequestCount: 0,
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
        bookedAt: now.subtract(const Duration(hours: 26)),
        editRequestCount: 0,
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
        bookedAt: now.subtract(const Duration(days: 2)),
        editRequestCount: 0,
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
        status: AppointmentStatus.done,
        consultationFee: 500,
        bookedAt: now.subtract(const Duration(days: 7)),
        outcome: AppointmentOutcome.done,
        editRequestCount: 0,
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
        status: AppointmentStatus.noShow,
        consultationFee: 700,
        bookedAt: now.subtract(const Duration(days: 4)),
        outcome: AppointmentOutcome.noShow,
        editRequestCount: 0,
      ),
    ];
  }
}
