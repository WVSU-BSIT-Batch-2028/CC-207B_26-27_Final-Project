import 'vital_sign.dart';

/// One past or current condition in a patient's medical history.
class MedicalHistoryEntry {
  const MedicalHistoryEntry({required this.condition, required this.diagnosedYear});

  /// e.g. "Hypertension"
  final String condition;

  /// Year the condition was diagnosed, e.g. 2020.
  final int diagnosedYear;
}

/// The "Records" part of a patient's full record (doctor side): medical
/// history, allergies, immunizations and latest vitals.
///
/// Vitals use the same [VitalSign] model as the patient's Home screen, so
/// the numbers are formatted the same way everywhere.
class PatientRecord {
  const PatientRecord({
    required this.patientId,
    required this.history,
    required this.allergies,
    required this.immunizations,
    required this.vitals,
  });

  /// Same id as the matching Patient.
  final String patientId;

  /// Diagnosed conditions. Empty means none recorded.
  final List<MedicalHistoryEntry> history;

  /// Known allergies. Empty means none.
  final List<String> allergies;

  /// Vaccines received, e.g. "Influenza (2024)". Empty means none.
  final List<String> immunizations;

  /// Latest vitals (blood pressure, heart rate, weight).
  final List<VitalSign> vitals;
}
