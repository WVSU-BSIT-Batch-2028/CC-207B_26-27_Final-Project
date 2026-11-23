import 'customer_notification_preferences.dart';
import 'customer_profile.dart';

/// Everything the profile home screen needs from the database.
class CustomerProfileOverview {
  const CustomerProfileOverview({
    required this.profile,
    required this.savedAddressCount,
    required this.notificationPreferences,
    this.avatarPublicUrl,
    this.passwordLastUpdatedAt,
  });

  final CustomerProfile profile;
  final int savedAddressCount;
  final CustomerNotificationPreferences notificationPreferences;
  final String? avatarPublicUrl;
  final DateTime? passwordLastUpdatedAt;
}