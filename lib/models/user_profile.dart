import 'user_role.dart';

/// Personal information shown and edited in Profile.
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

  /// Empty starting values; name and email come from the signed-in account.
  static UserProfile defaultsFor(UserRole role) {
    return const UserProfile(fullName: '', email: '');
  }
}

/// One toggle on the Notifications screen.
class NotificationOption {
  const NotificationOption(this.key, this.title, this.subtitle);
  final String key;
  final String title;
  final String subtitle;
}
