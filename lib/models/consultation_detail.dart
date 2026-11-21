/// The full record of one past consultation, shown in the "Medical Record"
/// popup (Consultation Details).
///
/// Records Overview only needs a summary ([HealthRecord]); this holds the
/// doctor's notes. The Appointments owner builds the screen where the doctor
/// WRITES these notes, so agree with her on these field names.
class ConsultationDetail {
  const ConsultationDetail({
    required this.id,
    required this.doctorName,
    required this.department,
    required this.type,
    required this.date,
    required this.diagnosis,
    required this.treatment,
  });

  /// Same id as the matching HealthRecord.
  final String id;

  /// e.g. "Dr. Maria Santos"
  final String doctorName;

  /// e.g. "General Consultation"
  final String department;

  /// e.g. "Consultation"
  final String type;

  /// Date of the visit.
  final DateTime date;

  /// "Assessment / Diagnosis" text written by the doctor.
  final String diagnosis;

  /// "Treatment / Recommendations" text written by the doctor.
  final String treatment;
}
