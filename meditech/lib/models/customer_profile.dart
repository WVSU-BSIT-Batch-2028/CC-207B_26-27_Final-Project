// The details a customer saved when they signed up
class CustomerProfile {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String mobile;
  final String email;
  final String birthdate;
  final String consentVersion;
  final String? avatarPath;

  const CustomerProfile({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.mobile,
    required this.email,
    required this.birthdate,
    required this.consentVersion,
    this.avatarPath,
  });

  String get fullName {
    final middle = middleName;
    if (middle == null || middle.isEmpty) return '$firstName $lastName';
    return '$firstName $middle $lastName';
  }

  String get displayMobile {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('09')) {
      return '+63 ${digits.substring(1, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    return mobile;
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
      avatarPath: json['avatar_path'] as String?,
    );
  }

  CustomerProfile copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? mobile,
    String? email,
    String? birthdate,
    String? consentVersion,
    String? avatarPath,
  }) {
    return CustomerProfile(
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      birthdate: birthdate ?? this.birthdate,
      consentVersion: consentVersion ?? this.consentVersion,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}