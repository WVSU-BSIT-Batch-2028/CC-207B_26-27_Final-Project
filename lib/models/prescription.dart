/// A medicine that a doctor prescribed to the patient.
///
/// This model is shared by every Prescriptions screen (list, details,
/// reminder, history) so they all show the same data. It holds plain data
/// only: no widgets and no storage code.
class Prescription {
  /// Creates a prescription. Fields marked `required` must always be given.
  const Prescription({
    required this.id,
    required this.medicineName,
    required this.strength,
    required this.form,
    required this.instruction,
    required this.durationDays,
    required this.startDate,
    required this.prescribedBy,
    required this.doctorPhone,
    required this.prescribedOn,
    this.refillDate,
    this.lastRefill,
    this.notes,
  });

  /// Unique id, used later to open the details screen and save reminders.
  final String id;

  /// Medicine name only, e.g. "Amoxicillin".
  final String medicineName;

  /// Strength, e.g. "500mg".
  final String strength;

  /// Type of medicine, e.g. "Capsule" or "Tablet".
  final String form;

  /// Short instruction shown on the card, e.g. "Take 1 capsule - 2x a day".
  final String instruction;

  /// How many days the patient should take it.
  final int durationDays;

  /// First day of the treatment.
  final DateTime startDate;

  /// Doctor who wrote the prescription.
  final String prescribedBy;

  /// Doctor's contact number (shown on the details screen).
  final String doctorPhone;

  /// Date the prescription was written.
  final DateTime prescribedOn;

  /// Date a refill becomes available. Null when no refill is planned.
  final DateTime? refillDate;

  /// Date of the most recent refill (shown in History Details).
  final DateTime? lastRefill;

  /// Doctor's extra instructions, e.g. "Take after meals" (HCI feedback).
  final String? notes;

  /// Card title, e.g. "Amoxicillin 500mg".
  String get title => '$medicineName $strength';

  /// Last day of the treatment as a date with no time.
  ///
  /// Built with the DateTime constructor (not `add(Duration)`) so the result
  /// is always midnight of the correct calendar day.
  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + durationDays);

  /// The final day the patient takes the medicine (the day before [endDate]).
  DateTime get lastDay => DateTime(
        startDate.year,
        startDate.month,
        startDate.day + durationDays - 1,
      );

  /// True while the treatment period has not finished yet.
  ///
  /// [now] can be passed in so tests do not depend on the real clock.
  bool isActiveOn(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return today.isBefore(endDate);
  }

  /// How many days a prescription stays in the Active list after its course
  /// (or its refill date) so the patient can still request the refill.
  static const int refillGraceDays = 3;

  /// True while the prescription belongs in the Active list.
  ///
  /// That is while the course runs, plus a short window after it when a
  /// refill is available. Without this, a refill date on or after the end of
  /// the course would send the prescription to History at the same moment the
  /// refill opens, so "Request Refill" could never be used.
  bool isListedActiveOn(DateTime now) {
    if (isActiveOn(now)) return true;
    final refill = refillDate;
    if (refill == null || !isRefillAvailableOn(now)) return false;
    final refillDay = DateTime(refill.year, refill.month, refill.day);
    final last = refillDay.isAfter(endDate) ? refillDay : endDate;
    final until =
        DateTime(last.year, last.month, last.day + refillGraceDays);
    final today = DateTime(now.year, now.month, now.day);
    return today.isBefore(until);
  }

  /// True once the first day of the treatment has arrived. Before that the
  /// medicine cannot be marked as taken and no reminder pops up.
  bool hasStartedOn(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return !start.isAfter(today);
  }

  /// True when a refill date is set and that day has arrived.
  ///
  /// Used by Prescription Details to enable or disable "Request Refill".
  bool isRefillAvailableOn(DateTime now) {
    final refill = refillDate;
    if (refill == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final refillDay = DateTime(refill.year, refill.month, refill.day);
    return !refillDay.isAfter(today);
  }
}
