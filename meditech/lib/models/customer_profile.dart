// The details a customer saved when they signed up
class CustomerProfile {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String mobile;
  final String email;
  final String birthdate;
  final String consentVersion;

  const CustomerProfile({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.mobile,
    required this.email,
    required this.birthdate,
    required this.consentVersion,
  });

  String get fullName {
    final middle = middleName;
    if (middle == null || middle.isEmpty) return '$firstName $lastName';
    return '$firstName $middle $lastName';
  }

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    final middle = json['middle_name'] as String?;
    return CustomerProfile(
      firstName: json['first_name'] as String,
      middleName: middle,
      lastName: json['last_name'] as String,
      mobile: json['mobile'] as String,
      email: json['email'] as String,
      birthdate: json['birthdate'].toString(),
      consentVersion: json['consent_version'] as String,
    );
  }
}