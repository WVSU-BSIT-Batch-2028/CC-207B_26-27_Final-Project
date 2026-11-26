import 'appointment_status.dart';

/// Kind of Recent Activity row (sets its icon).
enum ActivityType { labResult, prescription, message }

/// One row in the doctor's "Recent Activity" list.
class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final ActivityType type;
  final String title;
  final String subtitle;
  final String time;
}

/// One appointment in the doctor's "Today's Appointments" list.
class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.time,
    required this.patientName,
    required this.reason,
    required this.isVideo,
    required this.status,
  });

  final String id;
  final String time; // e.g. "9:00 AM"
  final String patientName;
  final String reason;
  final bool isVideo;
  final AppointmentStatus status;
}

/// Everything the doctor Home and Dashboard screens need.
class DoctorDashboardData {
  const DoctorDashboardData({
    required this.doctorShortName,
    required this.specialty,
    required this.todayAppointments,
    required this.patients,
    required this.prescriptions,
    required this.labResults,
    required this.nextUp,
    required this.appointments,
    required this.activities,
  });

  final String doctorShortName; // e.g. "Dr. Santos"
  final String specialty;
  final int todayAppointments;
  final int patients;
  final int prescriptions;
  final int labResults;
  final String? nextUp; // e.g. "1:30 PM · Lab Result Review"
  final List<DoctorAppointment> appointments; // today's list (may be shorter than the count)
  final List<ActivityItem> activities;
}
