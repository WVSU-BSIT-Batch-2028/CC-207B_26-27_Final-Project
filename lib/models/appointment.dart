import 'appointment_status.dart';

/// Represents the outcome of an appointment after its scheduled date.
enum AppointmentOutcome {
  none,
  done,
  noShow,
}

/// Represents the review status of a patient's requested appointment changes.
enum ChangeRequestStatus {
  pending,
  approved,
  rejected,
}

/// Stores the new booking details requested by a patient.
///
/// These changes do not replace the original appointment until approved
/// by the doctor.
class AppointmentChangeRequest {
  const AppointmentChangeRequest({
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    required this.isVideo,
    required this.consultationFee,
    required this.reminderEnabled,
    required this.requestedAt,
    this.doctorId,
    this.status = ChangeRequestStatus.pending,
  });

  /// Firebase UID of the requested doctor.
  final String? doctorId;

  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final bool isVideo;
  final double? consultationFee;
  final bool reminderEnabled;
  final DateTime requestedAt;
  final ChangeRequestStatus status;
}

/// Represents a patient's scheduled medical appointment.
///
/// Shared by the patient and doctor appointment modules.
class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.doctorId,
    this.isVideo = false,
    this.status = AppointmentStatus.confirmed,
    this.consultationFee,
    this.reminderEnabled = false,
    this.meetingUrl,
    this.patientName,
    this.patientId,
    this.bookedAt,
    this.outcome = AppointmentOutcome.none,
    this.changeRequest,
    this.editRequestCount = 0,
  });

  final String id;
  final String title;

  /// Firebase UID of the doctor assigned to this appointment.
  ///
  /// Nullable to support existing appointment records created before
  /// doctor-specific assignment was implemented.
  final String? doctorId;

  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final bool isVideo;
  final AppointmentStatus status;
  final double? consultationFee;
  final bool reminderEnabled;

  /// Google Meet link for video consultations, if available.
  final String? meetingUrl;

  /// Patient's display name, if available.
  final String? patientName;

  /// Patient's unique identifier for future backend integration.
  final String? patientId;

  /// Original date and time when the appointment was booked.
  ///
  /// Used to determine whether the patient is still within the
  /// 24-hour appointment change request period.
  final DateTime? bookedAt;

  /// Indicates whether the consultation was completed or missed.
  final AppointmentOutcome outcome;

  /// Pending or reviewed request to change the appointment details.
  final AppointmentChangeRequest? changeRequest;

  /// Total number of edit requests submitted by the patient.
  ///
  /// Every submitted request counts, including requests that are later
  /// approved or rejected. The maximum allowed count is two.
  final int editRequestCount;

  /// Number of edit requests the patient can still submit.
  int get remainingEditRequests => (2 - editRequestCount).clamp(0, 2);
}
