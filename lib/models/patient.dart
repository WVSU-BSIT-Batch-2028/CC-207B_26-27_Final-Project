/// One patient in the doctor's Patients list.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    this.age,
    this.sex,
    this.phone,
    this.condition,
    required this.lastVisit,
    required this.isActive,
  });

  /// Firebase UID of the patient.
  final String id;

  /// Patient's registered display name.
  final String name;

  /// Optional demographic information.
  final int? age;
  final String? sex;
  final String? phone;

  /// Main condition, when available.
  final String? condition;

  /// Date of the most recent appointment.
  final DateTime lastVisit;

  /// True when the patient has a pending or confirmed appointment.
  final bool isActive;
}
