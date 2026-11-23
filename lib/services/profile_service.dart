import 'dart:async' as async;

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_item.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import 'auth_service.dart';
import 'prescription_service.dart';

/// Saves personal information and notification toggles.
/// Reads the signed-in user's name/email from Firebase Auth & Firestore `users/{uid}`.
typedef NotificationPrefsMap = Map<String, bool>;

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

  async.Future<UserProfile> load(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final d = UserProfile.defaultsFor(role);

    String resolvedName = d.fullName;
    String resolvedEmail = d.email;

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        resolvedEmail = user.email ?? resolvedEmail;
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          resolvedName = user.displayName!.trim();
        }
        try {
          final data = await AuthService().getUserProfile(user.uid);
          final fsName = data?['fullName'] as String?;
          final fsEmail = data?['email'] as String?;
          if (fsName != null && fsName.trim().isNotEmpty) {
            resolvedName = fsName.trim();
          }
          if (fsEmail != null && fsEmail.trim().isNotEmpty) {
            resolvedEmail = fsEmail.trim();
          }
        } catch (_) {
          // Fall back to FirebaseAuth displayName/email if Firestore is offline.
        }
      }
    }

    String read(String field, String fallback) =>
        prefs.getString(_key(role, field)) ?? fallback;

    return UserProfile(
      fullName: Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null
          ? resolvedName
          : read('fullName', resolvedName),
      email: resolvedEmail,
      mobile: read('mobile', d.mobile),
      birthDate: read('birthDate', d.birthDate),
      gender: read('gender', d.gender),
      address: read('address', d.address),
    );
  }

  /// Saves personal information locally and updates `users/{uid}` in Firestore when signed in.
  async.Future<void> save(UserRole role, UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(role, 'fullName'), profile.fullName);
    await prefs.setString(_key(role, 'mobile'), profile.mobile);
    await prefs.setString(_key(role, 'birthDate'), profile.birthDate);
    await prefs.setString(_key(role, 'gender'), profile.gender);
    await prefs.setString(_key(role, 'address'), profile.address);

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(profile.fullName);
        await fs.FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'fullName': profile.fullName},
          fs.SetOptions(merge: true),
        );
      }
    }
  }

  /// MOCK notification history (newest first). Which items were read is saved
  /// on the device. Replace the sample list with the real backend later.
  async.Future<List<NotificationItem>> loadNotificationHistory(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = (prefs.getStringList('${role.name}_notif_read') ?? const <String>[]).toSet();
    final now = DateTime.now();
    DateTime at(int daysAgo, int hour, int minute) =>
        DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

    final items = role == UserRole.doctor
        ? <NotificationItem>[
            NotificationItem(id: 'd1', categoryKey: 'lab', title: 'New lab result available', message: 'Patient: Mark Villanueva', time: at(0, 10, 30)),
            NotificationItem(id: 'd2', categoryKey: 'prescription', title: 'Prescription updated', message: 'Patient: Ana Dela Cruz', time: at(0, 9, 45)),
            NotificationItem(id: 'd3', categoryKey: 'appointment', title: 'Appointment cancelled', message: 'Liza Ramos cancelled the 3:00 PM consultation.', time: at(0, 7, 50)),
            NotificationItem(id: 'd4', categoryKey: 'appointment', title: 'Appointment request pending', message: 'Paolo Mendoza asked for a follow-up on Thursday.', time: at(1, 15, 10)),
            NotificationItem(id: 'd5', categoryKey: 'system', title: 'System update', message: 'New features are available in Health360.', time: at(2, 18, 0)),
          ]
        : <NotificationItem>[
            NotificationItem(id: 'n1', categoryKey: 'appointments', title: 'Appointment tomorrow', message: 'Reminder: General Consultation with Dr. Maria Santos tomorrow at 10:00 AM.', time: at(0, 9, 0)),
            NotificationItem(id: 'n2', categoryKey: 'prescriptions', title: 'Time to take Vitamin D3', message: '1000 IU, scheduled for 8:00 AM.', time: at(0, 8, 0)),
            NotificationItem(id: 'n3', categoryKey: 'lab_results', title: 'Lab results available', message: 'Your blood test results are ready to view in Records.', time: at(1, 16, 30)),
            NotificationItem(id: 'n4', categoryKey: 'appointments', title: 'Appointment confirmed', message: 'Your visit on Monday at 10:00 AM is confirmed.', time: at(2, 11, 15)),
            NotificationItem(id: 'n5', categoryKey: 'health', title: 'Daily check-in', message: 'How did you sleep last night? Add a reading in Health at a Glance.', time: at(3, 7, 30)),
          ];

    // Doctor: one entry for every refill request still waiting for an answer.
    if (role == UserRole.doctor) {
      items.addAll(await _refillNotifications());
    }

    items.sort((a, b) => b.time.compareTo(a.time));
    return [for (final i in items) i.copyWith(read: readIds.contains(i.id))];
  }

  /// Notification entries built from the refill requests that patients sent
  /// to this doctor and that nobody has answered yet. They disappear once the
  /// doctor approves or declines. If they cannot be loaded, the sample
  /// notifications still show.
  async.Future<List<NotificationItem>> _refillNotifications() async {
    try {
      final notices = await PrescriptionService.instance.fetchPendingRefillNotices();
      return [
        for (final n in notices)
          NotificationItem(
            id: 'refill_${n.id}',
            categoryKey: 'prescription',
            title: 'Refill requested',
            message: '${n.patientName} asked to refill ${n.medicineTitle}.',
            time: n.requestedAt,
          ),
      ];
    } catch (_) {
      return const <NotificationItem>[];
    }
  }

  async.Future<void> markNotificationsRead(UserRole role, Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${role.name}_notif_read';
    final all = (prefs.getStringList(key) ?? const <String>[]).toSet()..addAll(ids);
    await prefs.setStringList(key, all.toList());
  }

  async.Future<NotificationPrefsMap> loadNotificationPrefs(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final o in notificationOptions(role))
        o.key: prefs.getBool('${role.name}_notif_${o.key}') ?? true,
    };
  }

  async.Future<void> setNotificationPref(UserRole role, String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${role.name}_notif_$key', value);
  }
}