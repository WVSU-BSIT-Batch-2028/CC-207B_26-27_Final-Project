/// One prescription written for a patient.
///
/// Shown in the doctor's Patient Prescriptions list and created by the Add
/// Prescription form.
class DoctorPrescription {
  const DoctorPrescription({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.form,
    required this.timesPerDay,
    required this.durationDays,
    required this.startDate,
    this.refillDate,
    this.notes,
  });

  /// Unique id.
  final String id;

  /// e.g. "Amoxicillin"
  final String medicineName;

  /// Strength of one dose, e.g. "500mg".
  final String dosage;

  /// What the medicine comes as, e.g. "capsule" or "tablet".
  final String form;

  /// How many times a day to take it, e.g. 2.
  final int timesPerDay;

  /// How many days the patient takes it.
  final int durationDays;

  /// First day of the prescription.
  final DateTime startDate;

  /// When the patient can refill it, if a refill is planned.
  final DateTime? refillDate;

  /// The doctor's extra instructions, e.g. "Take after meals".
  final String? notes;

  /// e.g. "Amoxicillin 500mg"
  String get title => '$medicineName $dosage';

  /// e.g. "Take 1 capsule - 2x a day"
  String get instructionText => 'Take 1 $form - ${timesPerDay}x a day';

  /// Last day of the prescription.
  DateTime get endDate => startDate.add(Duration(days: durationDays));

  /// Turns the prescription into a map, so it can be saved on the device as JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineName': medicineName,
        'dosage': dosage,
        'form': form,
        'timesPerDay': timesPerDay,
        'durationDays': durationDays,
        'startDate': startDate.toIso8601String(),
        'refillDate': refillDate?.toIso8601String(),
        'notes': notes,
      };

  /// Builds a prescription back from the map saved by [toJson].
  factory DoctorPrescription.fromJson(Map<String, dynamic> json) {
    final refill = json['refillDate'] as String?;
    return DoctorPrescription(
      id: json['id'] as String,
      medicineName: json['medicineName'] as String,
      dosage: json['dosage'] as String,
      form: json['form'] as String,
      timesPerDay: json['timesPerDay'] as int,
      durationDays: json['durationDays'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
      refillDate: refill == null ? null : DateTime.parse(refill),
      notes: json['notes'] as String?,
    );
  }
}
