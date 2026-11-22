/// One patient in the doctor's Patients list.
///
/// This is only the SUMMARY the list (and the Patient Details header) needs.
/// The full record (allergies, vitals, lab results, prescriptions) is loaded
/// separately by [id] when those screens are built.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.phone,
    required this.condition,
    required this.lastVisit,
    required this.isActive,
  });

  /// Unique id, used later to load the patient's full record.
  final String id;

  /// Full name, e.g. "Jahna Erika Lagne".
  final String name;

  /// Age in years.
  final int age;

  /// e.g. "Female"
  final String sex;

  /// Contact number, e.g. "+63 912 345 6789".
  final String phone;

  /// Main condition from the latest visit, e.g. "Common Cold".
  final String condition;

  /// Date of the patient's latest visit.
  final DateTime lastVisit;

  /// True for patients currently under the doctor's care (the "Active" pill),
  /// false for past patients (the "History" pill).
  final bool isActive;
}
