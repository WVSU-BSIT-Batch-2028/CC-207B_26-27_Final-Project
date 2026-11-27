/// One scheduled medication intake for today.
class MedicationDose {
  const MedicationDose({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    this.taken = false,
  });

  final String id;
  final String name;
  final String dosage;
  final String time;
  final bool taken;

  MedicationDose copyWith({bool? taken}) => MedicationDose(
        id: id,
        name: name,
        dosage: dosage,
        time: time,
        taken: taken ?? this.taken,
      );
}
