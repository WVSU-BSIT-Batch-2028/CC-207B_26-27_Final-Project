/// The medical facts shown on the Patient Details screen.
///
/// The name, age, sex, phone and last visit come from [Patient] (already
/// loaded by the list). This holds what needs a separate load.
class PatientDetail {
  const PatientDetail({
    required this.patientId,
    required this.conditions,
    required this.allergies,
  });

  /// Same id as the matching Patient.
  final String patientId;

  /// Known medical conditions, e.g. ["Hypertension"]. Empty means none.
  final List<String> conditions;

  /// Known allergies, e.g. ["Penicillin"]. Empty means none.
  final List<String> allergies;
}
