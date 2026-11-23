
/// One patient in the doctor's Patients list.
///
/// This is only the SUMMARY the list (and the Patient Details header) needs.
/// The full record (allergies, vitals, lab results, prescriptions) is loaded
/// separately by [id] when those screens are built.
///
/// It is built from Firestore: the name comes from `users/{uid}`, the age,
/// sex, phone and condition from `patientProfiles/{uid}`, and the last visit
/// from the patient's most recent consultation. A patient who has no profile
/// or no visit yet simply has those values empty ([age], [sex], [phone] and
/// [lastVisit] are null).
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.condition,
    required this.isActive,
    this.age,
    this.sex,
    this.phone,
    this.lastVisit,
  });

  /// The patient's uid (same id as `users/{uid}`).
  final String id;

  /// Patient's registered display name.
  final String name;

  /// Main condition, e.g. "Common Cold".
  /// Uses "No condition recorded" if unknown.
  final String condition;

  /// True for patients currently under the doctor's care (the "Active" pill),
  /// false for past patients (the "History" pill).
  final bool isActive;

  /// Age in years, if the profile has it.
  final int? age;

  /// e.g. "Female", if the profile has it.
  final String? sex;

  /// Contact number, e.g. "+63 912 345 6789", if the profile has it.
  final String? phone;

  /// Date of the patient's latest consultation, or null if there is none yet.
  final DateTime? lastVisit;
}
