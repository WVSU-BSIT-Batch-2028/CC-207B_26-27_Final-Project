/// State of an appointment, shared by patient and doctor screens.
enum AppointmentStatus {
  pending,
  confirmed,
  cancelled,
  done,
  noShow,
}

/// Provides display labels for appointment statuses.
extension AppointmentStatusX on AppointmentStatus {
  /// Returns the label displayed in appointment status chips.
  String get label {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.done:
        return 'Done';
      case AppointmentStatus.noShow:
        return 'No-show';
    }
  }
}
