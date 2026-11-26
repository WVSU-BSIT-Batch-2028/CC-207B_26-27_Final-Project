/// How staff can reach a student. Full name is required; at least one of
/// email or phone is also required (checked in the forms and in the rules).
class ContactDetails {
  const ContactDetails({
    required this.fullName,
    this.email = '',
    this.phone = '',
  });

  final String fullName;
  final String email;
  final String phone;

  Map<String, dynamic> toJson() {
    return {'fullName': fullName, 'email': email, 'phone': phone};
  }

  factory ContactDetails.fromJson(Map<String, dynamic> json) {
    return ContactDetails(
      fullName: (json['fullName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }
}
