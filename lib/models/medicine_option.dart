/// A medicine the doctor can choose in the Add Prescription form, with the
/// doses it comes in. The dosage list depends on the medicine, so the doctor
/// cannot pick a dose that does not exist.
class MedicineOption {
  const MedicineOption({required this.name, required this.form, required this.dosages});

  /// e.g. "Amoxicillin"
  final String name;

  /// "capsule" or "tablet".
  final String form;

  /// The doses available, e.g. ["250mg", "500mg"].
  final List<String> dosages;
}

/// The medicines in the Add Prescription form (sample list for now).
const List<MedicineOption> kMedicineCatalog = [
  MedicineOption(name: 'Amoxicillin', form: 'capsule', dosages: ['250mg', '500mg']),
  MedicineOption(name: 'Paracetamol', form: 'tablet', dosages: ['250mg', '500mg']),
  MedicineOption(name: 'Cetirizine', form: 'tablet', dosages: ['5mg', '10mg']),
  MedicineOption(name: 'Ibuprofen', form: 'tablet', dosages: ['200mg', '400mg']),
  MedicineOption(name: 'Amlodipine', form: 'tablet', dosages: ['5mg', '10mg']),
];
