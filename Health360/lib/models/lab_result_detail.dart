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
///
/// In Firestore each value is a map inside the lab result's `values` list:
/// name, value, unit, range (text such as "13.0-17.0") and flag ("normal",
/// "low" or "high").
class LabValue {
  const LabValue({
    required this.name,
    required this.value,
    required this.unit,
    required this.rangeText,
    required this.flag,
  });

  /// Builds a value from one map of the `values` list.
  ///
  /// If the map has no usable `flag`, it is worked out from the range text
  /// when that can be read (e.g. "13.0-17.0"), otherwise the value is normal.
  factory LabValue.fromMap(Map<String, dynamic> map) {
    final raw = map['value'];
    final value = raw is num ? raw.toDouble() : (double.tryParse('$raw') ?? 0);
    final range = (map['range'] ?? '').toString();
    return LabValue(
      name: (map['name'] ?? 'Test').toString(),
      value: value,
      unit: (map['unit'] ?? '').toString(),
      rangeText: range,
      flag: _parseFlag(map['flag'], range, value),
    );
  }

  /// e.g. "Hemoglobin"
  final String name;

  /// The measured number.
  final double value;

  /// e.g. "g/dL". Can be empty.
  final String unit;

  /// Normal reference range as text, e.g. "13.0-17.0".
  final String rangeText;

  /// Low, high or normal.
  final LabFlag flag;

  /// e.g. "14.2 g/dL" ("42%" has no space before the percent sign).
  String get resultText {
    final number = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
    if (unit.isEmpty) return number;
    return unit == '%' ? '$number%' : '$number $unit';
  }

  /// Reads the flag text; falls back to comparing [value] with the range.
  static LabFlag _parseFlag(Object? raw, String range, double value) {
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'high' || text == 'h') return LabFlag.high;
    if (text == 'low' || text == 'l') return LabFlag.low;
    if (text == 'normal' || text == 'n') return LabFlag.normal;

    final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[-\u2013]\s*(-?\d+(?:\.\d+)?)\s*$').firstMatch(range);
    if (match != null) {
      final min = double.parse(match.group(1)!);
      final max = double.parse(match.group(2)!);
      if (value < min) return LabFlag.low;
      if (value > max) return LabFlag.high;
    }
    return LabFlag.normal;
  }
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
