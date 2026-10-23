/// Kinds of vitals shown in "Health at a Glance".
enum VitalType { heartRate, bloodPressure, weight, sleep }

/// Whether a reading is in its usual range or worth keeping an eye on.
enum VitalStatus { normal, watch }

/// One health metric with a short 7-day trend for the sparkline.
class VitalSign {
  const VitalSign({
    required this.type,
    required this.label,
    required this.value,
    required this.unit,
    required this.trend,
    this.status = VitalStatus.normal,
  });

  final VitalType type;
  final String label;
  final String value;
  final String unit;
  final List<double> trend;
  final VitalStatus status;
}
