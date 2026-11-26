/// The two kinds of entry that appear in the patient's Records list.
enum RecordType { consultation, labResult }

/// One row in Records Overview (a past consultation or a lab result).
///
/// This is only the SUMMARY the list needs. The detail screens (Consultation
/// Details, Lab Result Details) will load the full data by [id] later.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  /// Unique id, used later to open the right detail screen.
  final String id;

  /// Consultation or lab result. Decides the icon and which detail screen opens.
  final RecordType type;

  /// Main line on the card, e.g. "General Consultation".
  final String title;

  /// Second line: the doctor's name (consultation) or the test name (lab result).
  final String subtitle;

  /// Date of the visit or of the lab test.
  final DateTime date;
}
