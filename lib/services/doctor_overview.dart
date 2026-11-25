import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/prescription.dart';

/// The four Quick Overview numbers on doctor Home (no Firebase, so it is
/// unit tested):
/// - Today's appointments: today, not cancelled.
/// - Active prescriptions: not finished yet.
/// - Active patients: an active prescription, or a pending/confirmed
///   appointment from today on.
/// - Today's lab results: tested or entered today.
class DoctorOverview {
  const DoctorOverview({
    required this.todayAppointments,
    required this.activePatients,
    required this.activePrescriptions,
    required this.todayLabResults,
  });

  final int todayAppointments;
  final int activePatients;
  final int activePrescriptions;
  final int todayLabResults;

  /// Counts the four numbers. Each lab result gives its test date and the
  /// date it was entered (either may be null).
  static DoctorOverview compute({
    required List<Appointment> appointments,
    required List<({String patientId, Prescription prescription})> prescriptions,
    required List<({DateTime? date, DateTime? enteredAt})> labResultDates,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    final todayAppointments = appointments
        .where((a) => _sameDay(a.dateTime, now) && a.status != AppointmentStatus.cancelled)
        .length;

    final active = [
      for (final p in prescriptions)
        if (p.prescription.isActiveOn(now)) p,
    ];

    final patients = <String>{
      for (final p in active)
        if (p.patientId.isNotEmpty) p.patientId,
      for (final a in appointments)
        if ((a.patientId ?? '').isNotEmpty &&
            !a.dateTime.isBefore(today) &&
            (a.status == AppointmentStatus.pending ||
                a.status == AppointmentStatus.confirmed))
          a.patientId!,
    };

    final todayLabs = labResultDates.where((l) {
      final date = l.date;
      final entered = l.enteredAt;
      return (date != null && _sameDay(date, now)) ||
          (entered != null && _sameDay(entered, now));
    }).length;

    return DoctorOverview(
      todayAppointments: todayAppointments,
      activePatients: patients.length,
      activePrescriptions: active.length,
      todayLabResults: todayLabs,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
