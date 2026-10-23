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
    required this.activities,
  });

  final String doctorShortName; // e.g. "Dr. Santos"
  final String specialty;
  final int todayAppointments;
  final int patients;
  final int prescriptions;
  final int labResults;
  final String? nextUp; // e.g. "2:30 PM · General Consultation"
  final List<ActivityItem> activities;
}
