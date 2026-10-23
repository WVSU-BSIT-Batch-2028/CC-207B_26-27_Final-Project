/// Which side of Health360 is being viewed.
/// There is no login yet, so the role gate lets you pick one (demo access).
enum UserRole { patient, doctor }

extension UserRoleX on UserRole {
  String get label => this == UserRole.patient ? 'Patient' : 'Doctor';
}
