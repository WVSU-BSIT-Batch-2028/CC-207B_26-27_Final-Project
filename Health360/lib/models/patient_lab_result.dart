/// One lab result in a patient's list on the doctor side (the "Lab Results"
/// pill of Patient Records). Only the summary the list needs; the values and
/// notes are loaded by [id] when the result is opened.
class PatientLabResult {
  const PatientLabResult({
    required this.id,
    required this.testName,
    required this.date,
  });

  /// Unique id, used later to open the full result.
  final String id;

  /// e.g. "Complete Blood Count"
  final String testName;

  /// Date of the lab test.
  final DateTime date;
}
