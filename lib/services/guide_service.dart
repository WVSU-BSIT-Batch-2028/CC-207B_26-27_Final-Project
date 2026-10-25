import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

/// Remembers whether the first-time "How to use" guide was already shown,
/// separately for each role (patient / doctor).
class GuideService {
  GuideService._();
  static final GuideService instance = GuideService._();

  String _key(UserRole role) => 'guide_seen_${role.name}';

  Future<bool> hasSeen(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(role)) ?? false;
  }

  Future<void> markSeen(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(role), true);
  }
}
