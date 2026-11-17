// One person who works at a pharmacy branch
class Employee {
  final String accountId;
  final String displayId;
  final String? username;
  final String role;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? prcLicenseNo;
  final DateTime? prcLicenseExpiry;
  final String licenseStatus;
  final bool isActive;

  const Employee({
    required this.accountId,
    required this.displayId,
    this.username,
    required this.role,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.prcLicenseNo,
    this.prcLicenseExpiry,
    required this.licenseStatus,
    required this.isActive,
  });

  String get fullName {
    final middle = middleName;
    if (middle == null || middle.isEmpty) return '$firstName $lastName';
    return '$firstName $middle $lastName';
  }

  bool get isOwner => role == 'owner';
  bool get isPharmacist => role == 'pharmacist';

  String get roleLabel => switch (role) {
        'owner' => 'Owner',
        'pharmacist' => 'Pharmacist',
        _ => 'Staff',
      };

  // Only a verified license that has not run out lets someone confirm or release
  bool hasValidLicense(DateTime today) {
    final expiry = prcLicenseExpiry;
    if (licenseStatus != 'verified' || expiry == null) return false;
    final day = DateTime(today.year, today.month, today.day);
    return !expiry.isBefore(day);
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    final expiry = json['prc_license_expiry'];
    return Employee(
      accountId: json['account_id'] as String,
      displayId: json['display_id'] as String,
      username: json['username'] as String?,
      role: json['role'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      prcLicenseNo: json['prc_license_no'] as String?,
      prcLicenseExpiry: expiry == null ? null : DateTime.parse(expiry.toString()),
      licenseStatus: json['license_status'] as String? ?? 'none',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
