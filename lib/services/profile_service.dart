import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../models/user_role.dart';

/// Saves personal information and notification toggles on the device.
/// (Local data persistence; swap for Firebase / MySQL later.)
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static List<NotificationOption> notificationOptions(UserRole role) {
    if (role == UserRole.doctor) {
      return const [
        NotificationOption('appointment', 'Appointment Reminder', 'Upcoming consultations on your schedule'),
        NotificationOption('prescription', 'Prescription Reminder', 'Prescriptions waiting for review'),
        NotificationOption('lab', 'Lab Results Available', 'New lab results from your patients'),
        NotificationOption('system', 'System Update', 'New features and maintenance notices'),
      ];
    }
    return const [
      NotificationOption('appointments', 'Appointments', 'Reminders about upcoming consultations'),
      NotificationOption('prescriptions', 'Prescriptions', 'Intake and refill reminders'),
      NotificationOption('lab_results', 'Lab Results', 'When new results are available'),
      NotificationOption('health', 'Health Reminders', 'Gentle check-ins and health tips'),
    ];
  }

  String _key(UserRole role, String field) => '${role.name}_profile_$field';

  Future<UserProfile> load(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final d = UserProfile.defaultsFor(role);
    String read(String field, String fallback) =>
        prefs.getString(_key(role, field)) ?? fallback;
    return UserProfile(
      fullName: read('fullName', d.fullName),
      email: d.email,
      mobile: read('mobile', d.mobile),
      birthDate: read('birthDate', d.birthDate),
      gender: read('gender', d.gender),
      address: read('address', d.address),
    );
  }

  /// Simulates a short network round-trip so the Save button shows loading.
  Future<void> save(UserRole role, UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(role, 'fullName'), profile.fullName);
    await prefs.setString(_key(role, 'mobile'), profile.mobile);
    await prefs.setString(_key(role, 'birthDate'), profile.birthDate);
    await prefs.setString(_key(role, 'gender'), profile.gender);
    await prefs.setString(_key(role, 'address'), profile.address);
  }

  Future<Map<String, bool>> loadNotificationPrefs(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final o in notificationOptions(role))
        o.key: prefs.getBool('${role.name}_notif_${o.key}') ?? true,
    };
  }

  Future<void> setNotificationPref(UserRole role, String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${role.name}_notif_$key', value);
  }
}
