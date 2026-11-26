/// Which side of Health360 is being viewed.
/// Saved as `role` in `users/{uid}`; decides which shell opens after login.
enum UserRole { patient, doctor }

extension UserRoleX on UserRole {
  String get label => this == UserRole.patient ? 'Patient' : 'Doctor';
}
