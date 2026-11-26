import 'appointment.dart';
import 'medication_dose.dart';
import 'vital_sign.dart';

/// Everything the patient Home screen needs, loaded in a single call.
class DashboardData {
  const DashboardData({
    required this.patientFirstName,
    required this.nextAppointment,
    required this.vitals,
    required this.doses,
  });

  final String patientFirstName;
  final Appointment? nextAppointment;
  final List<VitalSign> vitals;
  final List<MedicationDose> doses;

  bool get isEmpty =>
      nextAppointment == null && vitals.isEmpty && doses.isEmpty;

  int get takenCount => doses.where((d) => d.taken).length;

  /// Returns a copy where the vital of the same type is replaced by [updated].
  DashboardData withVital(VitalSign updated) => DashboardData(
        patientFirstName: patientFirstName,
        nextAppointment: nextAppointment,
        vitals: [
          for (final v in vitals)
            if (v.type == updated.type) updated else v,
        ],
        doses: doses,
      );

  DashboardData withDoseToggled(String doseId) => DashboardData(
        patientFirstName: patientFirstName,
        nextAppointment: nextAppointment,
        vitals: vitals,
        doses: [
          for (final d in doses)
            if (d.id == doseId) d.copyWith(taken: !d.taken) else d,
        ],
      );
}
