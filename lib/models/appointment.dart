import 'appointment_status.dart';

/// Represents a booked consultation.
///
/// Stores the appointment information shared by the patient and doctor
/// appointment screens.
class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.isVideo = false,
    this.status = AppointmentStatus.confirmed,
  });

  /// Unique identifier of the appointment.
  final String id;

  /// Type or title of the consultation.
  final String title;

  /// Name of the assigned doctor.
  final String doctorName;

  /// Medical specialty of the doctor.
  final String specialty;

  /// Scheduled appointment date and time.
  final DateTime dateTime;

  /// Clinic location or consultation location.
  final String location;

  /// Whether the consultation is conducted through video.
  final bool isVideo;

  /// Current appointment status.
  final AppointmentStatus status;
}