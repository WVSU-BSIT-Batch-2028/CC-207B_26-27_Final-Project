/// Represents a doctor available for patient appointment booking.
///
/// Stores the doctor's basic information and the next available
/// consultation schedule displayed in the booking flow.
class Doctor {
  /// Creates a doctor record.
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.category,
    required this.nextAvailable,
    required this.consultationType,
    required this.consultationFee,
  });

  /// Unique identifier for the doctor.
  final String id;

  /// Doctor's display name.
  final String name;

  /// Doctor's medical specialty.
  final String specialty;

  /// Category used by the specialty filter.
  final String category;

  /// Text describing the doctor's next available schedule.
  final String nextAvailable;

  /// Type of consultation offered.
  final String consultationType;

  /// Consultation fee in Philippine pesos.
  final double consultationFee;
}