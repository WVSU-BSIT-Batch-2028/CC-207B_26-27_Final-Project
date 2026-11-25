import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import 'auth_service.dart';

/// Remembers if the first-time guide was shown: per account in
/// `users/{uid}` (`guideSeen`), with a device copy for offline use.
class GuideService {
  GuideService._();
  static final GuideService instance = GuideService._();

  final AuthService _auth = AuthService();

  String _deviceKey(UserRole role, String? uid) =>
      uid == null ? 'guide_seen_${role.name}' : 'guide_seen_${role.name}_$uid';

  Future<bool> hasSeen(UserRole role) async {
    final uid = _auth.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_deviceKey(role, uid)) ?? false) return true;
    if (uid == null) return false;

    try {
      final account = await _auth.getUserProfile(uid);
      return account?['guideSeen'] == true;
    } catch (_) {
      return false; // when unsure, show the guide
    }
  }

  Future<void> markSeen(UserRole role) async {
    final uid = _auth.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceKey(role, uid), true);
    if (uid == null) return;

    try {
      // Allowed by the rules: users may update their own document.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'guideSeen': true}, SetOptions(merge: true));
      AuthService.forgetCachedProfile();
    } catch (_) {
      // The device copy still stops it from showing again.
    }
  }
}
