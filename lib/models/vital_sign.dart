/// Kinds of vitals shown in "Health at a Glance".
enum VitalType { heartRate, bloodPressure, weight, sleep }

/// Whether a reading is in its usual range or worth keeping an eye on.
enum VitalStatus { normal, watch }

/// Where a reading came from (only readings the patient owns are shown now).
enum ReadingSource { sample, you }

/// One measurement. Blood pressure uses [value] for systolic and
/// [secondary] for diastolic. Sleep stores hours (6.5 = 6h 30m).
class VitalReading {
  const VitalReading({
    required this.date,
    required this.value,
    this.secondary,
    this.source = ReadingSource.sample,
  });

  final DateTime date;
  final double value;
  final double? secondary;
  final ReadingSource source;
}

/// One health metric with its history.
class VitalSign {
  const VitalSign({
    required this.type,
    required this.label,
    required this.unit,
    required this.readings,
  });

  final VitalType type;
  final String label;
  final String unit;
  final List<VitalReading> readings; // oldest first

  /// False until there is a reading; check before using [latest].
  bool get hasReadings => readings.isNotEmpty;

  VitalReading get latest => readings.last;

  /// The last 7 readings (used for the trend line).
  List<VitalReading> get recent =>
      readings.length > 7 ? readings.sublist(readings.length - 7) : readings;

  List<double> get trend => [for (final r in recent) r.value];

  /// "--" when there is no reading yet.
  String get value => hasReadings ? vitalValueText(type, latest) : '--';

  VitalStatus get status =>
      hasReadings ? vitalStatusOf(type, latest) : VitalStatus.normal;

  VitalSign withReading(VitalReading reading) => VitalSign(
        type: type,
        label: label,
        unit: unit,
        readings: [...readings, reading],
      );
}

/// "72", "120/80", "58.4", "6h 30m"
String vitalValueText(VitalType type, VitalReading r) {
  switch (type) {
    case VitalType.heartRate:
      return r.value.round().toString();
    case VitalType.bloodPressure:
      return '${r.value.round()}/${(r.secondary ?? 0).round()}';
    case VitalType.weight:
      return r.value.toStringAsFixed(1);
    case VitalType.sleep:
      return _hoursText(r.value);
  }
}

/// Formats one number of this vital (lowest / average / highest).
String vitalStatText(VitalType type, double v) {
  switch (type) {
    case VitalType.heartRate:
    case VitalType.bloodPressure:
      return v.round().toString();
    case VitalType.weight:
      return v.toStringAsFixed(1);
    case VitalType.sleep:
      return _hoursText(v);
  }
}

String _hoursText(double hours) {
  final minutes = (hours * 60).round();
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// General ranges for a friendly label only (not medical advice).
VitalStatus vitalStatusOf(VitalType type, VitalReading r) {
  switch (type) {
    case VitalType.heartRate:
      return (r.value < 50 || r.value > 100) ? VitalStatus.watch : VitalStatus.normal;
    case VitalType.bloodPressure:
      final dia = r.secondary;
      final high = r.value >= 140 || (dia != null && dia >= 90);
      final low = r.value < 90 || (dia != null && dia < 60);
      return (high || low) ? VitalStatus.watch : VitalStatus.normal;
    case VitalType.weight:
      return VitalStatus.normal;
    case VitalType.sleep:
      return (r.value < 6 || r.value > 10) ? VitalStatus.watch : VitalStatus.normal;
  }
}
