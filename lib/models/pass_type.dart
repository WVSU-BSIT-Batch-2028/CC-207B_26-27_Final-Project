/// The four kinds of vehicle pass in the WVSU guidelines.
/// Each value carries the text shown on screens and the pass color.
enum PassType {
  studentWithParking('Student with parking', 'Navy Blue'),
  parentGuardianWithParking('Parent/guardian with parking', 'White'),
  facultyStaffWithParking('Faculty/staff with parking', 'WVSU Blue'),
  withoutParking('Without parking privilege', 'Yellow');

  const PassType(this.label, this.colorName);

  /// Readable name for screens.
  final String label;

  /// Color of the physical pass, from the guidelines.
  final String colorName;

  /// Only Yellow passes have no parking privilege.
  bool get hasParkingPrivilege => this != PassType.withoutParking;
}