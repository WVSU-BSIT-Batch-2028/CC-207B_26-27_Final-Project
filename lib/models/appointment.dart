/// A booked consultation.
class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.isVideo = false,
  });

  final String id;
  final String title;
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final bool isVideo;
}
