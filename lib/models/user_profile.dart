import 'user_role.dart';

/// Editable personal information (stored locally for now).
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    this.mobile = '',
    this.birthDate = '', // ISO yyyy-mm-dd, patient only
    this.gender = '',
    this.address = '',
  });

  final String fullName;
  final String email;
  final String mobile;
  final String birthDate;
  final String gender;
  final String address;

  UserProfile copyWith({
    String? fullName,
    String? mobile,
    String? birthDate,
    String? gender,
    String? address,
  }) =>
      UserProfile(
        fullName: fullName ?? this.fullName,
        email: email,
        mobile: mobile ?? this.mobile,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        address: address ?? this.address,
      );

  /// Sample data (fictional) used until the real backend exists.
  static UserProfile defaultsFor(UserRole role) {
    if (role == UserRole.doctor) {
      return const UserProfile(
        fullName: 'Dr. Michael Santos',
        email: 'michael.santos@example.com',
        mobile: '09123456789',
        gender: 'Male',
        address: 'Sta. Barbara, Iloilo',
      );
    }
    return const UserProfile(
      fullName: 'Jahna Reyes',
      email: 'jahna.reyes@example.com',
    );
  }
}

/// One toggle on the Notifications screen.
class NotificationOption {
  const NotificationOption(this.key, this.title, this.subtitle);
  final String key;
  final String title;
  final String subtitle;
}
