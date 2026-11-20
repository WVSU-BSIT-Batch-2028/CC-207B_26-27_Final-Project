import 'appointment_status.dart';

/// Represents a patient's scheduled medical appointment.
class Appointment {
  /// Creates an appointment with its basic information and optional details.
  const Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.isVideo = false,
    this.status = AppointmentStatus.confirmed,
    this.consultationFee,
    this.reminderEnabled = false,
    this.meetingUrl,
  });

  final String id;
  final String title;
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
}
