/// Whether a lab value is inside its reference range.
enum LabFlag {
  normal('Normal'),
  low('Low'),
  high('High');

  const LabFlag(this.label);

  /// Text shown next to an abnormal value (never colour alone).
  final String label;
}

/// One measured value in a lab result, e.g. Hemoglobin 14.2 g/dL.
class LabValue {
  const LabValue({
    required this.name,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    this.decimals = 1,
  });

  /// e.g. "Hemoglobin"
  final String name;

  /// The measured number.
  final double value;

  /// e.g. "g/dL". Can be empty.
  final String unit;

  /// Lower and upper end of the normal reference range.
  final double min;
  final double max;

  /// How many decimals to show for the value and the range.
  final int decimals;

  /// Low, high or normal, worked out by comparing [value] with the range.
  LabFlag get flag {
    if (value < min) return LabFlag.low;
    if (value > max) return LabFlag.high;
    return LabFlag.normal;
  }

  /// e.g. "14.2 g/dL" ("42%" has no space before the percent sign).
  String get resultText {
    final number = value.toStringAsFixed(decimals);
    if (unit.isEmpty) return number;
    return unit == '%' ? '$number%' : '$number $unit';
  }

  /// e.g. "13.0–17.0"
  String get rangeText => '${min.toStringAsFixed(decimals)}–${max.toStringAsFixed(decimals)}';
}

/// The full lab result shown in the "Lab Results" popup (Lab Result Details).
///
/// Records Overview only needs a summary ([HealthRecord]); this holds the
/// measured values and the doctor's notes.
class LabResultDetail {
  const LabResultDetail({
    required this.id,
    required this.testName,
    required this.patientName,
    required this.requestedBy,
    required this.status,
    required this.date,
    required this.results,
    required this.overallResult,
    required this.doctorNotes,
  });

  /// Same id as the matching HealthRecord.
  final String id;

  /// e.g. "CBC - Complete Blood Count"
  final String testName;
  final String patientName;

  /// The doctor who requested the test.
  final String requestedBy;

  /// e.g. "Complete"
  final String status;
  final DateTime date;

  /// Every measured value, shown as the results table.
  final List<LabValue> results;

  /// One-line summary written by the doctor.
  final String overallResult;
  final String doctorNotes;

  /// True if at least one value is outside its reference range.
  bool get hasAbnormal => results.any((v) => v.flag != LabFlag.normal);
}
