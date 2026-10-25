/// State of an appointment. Shown with AppointmentStatusChip everywhere
/// (patient and doctor) so the colours and labels stay the same.
enum AppointmentStatus { confirmed, pending, cancelled }

extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }
}
