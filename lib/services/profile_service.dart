import 'dart:async' as async;

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_format.dart';
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/health_record.dart';
import '../models/notification_item.dart';
import '../models/refill_request.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import 'appointment_service.dart';
import 'auth_service.dart';
import 'prescription_service.dart';
import 'records_service.dart';

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

    // Mobile, birth date, gender and address saved in `users/{uid}`
    // (null = not loaded from Firestore, so the copy on this device is used).
    Map<String, dynamic>? account;

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        resolvedEmail = user.email ?? resolvedEmail;
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          resolvedName = user.displayName!.trim();
        }
        try {
          final data = await AuthService().getUserProfile(user.uid);
          account = data;
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

    // Signed in: the value from Firestore. Otherwise (or for accounts saved
    // before this change) the copy kept on this device.
    String read(String field, String fallback) {
      final cloud = account?[field];
      if (cloud is String && cloud.trim().isNotEmpty) return cloud.trim();
      return prefs.getString(_key(role, field)) ?? fallback;
    }

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

  /// Saves personal information in `users/{uid}` (so it follows the user to
  /// any computer) and keeps a copy on this device for use without Firebase.
  /// The rules allow it: users may update their own document as long as the
  /// role does not change.
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
          {
            'fullName': profile.fullName,
            'mobile': profile.mobile,
            'birthDate': profile.birthDate,
            'gender': profile.gender,
            'address': profile.address,
            'updatedAt': fs.FieldValue.serverTimestamp(),
          },
          fs.SetOptions(merge: true),
        );
        // Otherwise the cached copy still holds the old name and Personal
        // Information / Home keep showing it until the next sign-in.
        AuthService.forgetCachedProfile();
      }
    }
  }

  /// Notification history (newest first), built from the user's real data
  /// in Firestore. Which items were read is saved on the device.
  ///
  /// Patient: upcoming, cancelled or changed appointments, answered refill
  /// requests, and new consultation notes or lab results (last 30 days).
  /// Doctor: bookings and change requests to review, cancellations, today's
  /// visits, and refill requests waiting for an answer.
  /// A part that cannot be loaded is skipped, so the rest still shows.
  async.Future<List<NotificationItem>> loadNotificationHistory(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = (prefs.getStringList('${role.name}_notif_read') ?? const <String>[]).toSet();

    final items = <NotificationItem>[
      ...await _appointmentNotifications(role),
      if (role == UserRole.doctor) ...await _refillNotifications(),
      if (role == UserRole.patient) ...await _refillAnswerNotifications(),
      if (role == UserRole.patient) ...await _recordNotifications(),
    ];

    items.sort((a, b) => b.time.compareTo(a.time));
    return [for (final i in items) i.copyWith(read: readIds.contains(i.id))];
  }

  /// "Mon, Nov 30 at 10:00 AM".
  String _when(DateTime d) => '${formatWeekdayDate(d)} at ${formatTime(d)}';

  /// Entries from the user's appointments (patient or doctor side).
  async.Future<List<NotificationItem>> _appointmentNotifications(UserRole role) async {
    final List<Appointment> all;
    try {
      all = await AppointmentService.instance.fetchAppointments();
    } catch (_) {
      return const <NotificationItem>[];
    }

    final now = DateTime.now();
    final soon = now.add(const Duration(days: 7));
    final doctor = role == UserRole.doctor;
    final category = doctor ? 'appointment' : 'appointments';
    final items = <NotificationItem>[];

    for (final a in all) {
      final upcoming = a.dateTime.isAfter(now);
      final who = doctor ? (a.patientName ?? 'A patient') : a.doctorName;
      final booked = a.bookedAt ?? now;
      final request = a.changeRequest;

      if (upcoming && a.status == AppointmentStatus.cancelled) {
        items.add(NotificationItem(
          id: 'apt_cancel_${a.id}',
          categoryKey: category,
          title: 'Appointment cancelled',
          message: doctor
              ? 'The consultation with $who on ${_when(a.dateTime)} was cancelled.'
              : 'Your consultation with $who on ${_when(a.dateTime)} was cancelled.',
          time: booked,
        ));
        continue;
      }

      if (doctor && upcoming && a.status == AppointmentStatus.pending) {
        items.add(NotificationItem(
          id: 'apt_new_${a.id}',
          categoryKey: category,
          title: 'New appointment to confirm',
          message: '$who booked ${a.specialty} on ${_when(a.dateTime)}.',
          time: booked,
        ));
      } else if (upcoming && a.dateTime.isBefore(soon)) {
        items.add(NotificationItem(
          id: 'apt_soon_${a.id}',
          categoryKey: category,
          title: a.status == AppointmentStatus.confirmed
              ? 'Upcoming appointment (confirmed)'
              : 'Upcoming appointment (waiting for the doctor)',
          message: '${a.specialty} with $who on ${_when(a.dateTime)}.',
          time: booked,
        ));
      }

      if (request != null && upcoming) {
        final status = request.status;
        if (doctor && status == ChangeRequestStatus.pending) {
          items.add(NotificationItem(
            id: 'apt_change_${a.id}_${request.requestedAt.millisecondsSinceEpoch}',
            categoryKey: category,
            title: 'Change request to review',
            message: '$who asked to move their appointment to ${_when(request.dateTime)}.',
            time: request.requestedAt,
          ));
        } else if (!doctor && status != ChangeRequestStatus.pending) {
          final approved = status == ChangeRequestStatus.approved;
          items.add(NotificationItem(
            id: 'apt_change_${a.id}_${request.requestedAt.millisecondsSinceEpoch}',
            categoryKey: category,
            title: approved ? 'Change request approved' : 'Change request declined',
            message: approved
                ? 'Your appointment is now on ${_when(a.dateTime)}.'
                : 'Your appointment stays on ${_when(a.dateTime)}.',
            time: request.requestedAt,
          ));
        }
      }
    }
    return items;
  }

  /// Patient: refill requests the doctor approved or declined.
  async.Future<List<NotificationItem>> _refillAnswerNotifications() async {
    try {
      final answers = await PrescriptionService.instance.fetchMyAnsweredRefills();
      return [
        for (final r in answers)
          NotificationItem(
            id: 'refill_${r.id}_${r.status.name}',
            categoryKey: 'prescriptions',
            title: r.status == RefillStatus.approved ? 'Refill approved' : 'Refill declined',
            message: r.status == RefillStatus.approved
                ? 'Your refill for ${r.medicineTitle} was approved.'
                : 'Your refill for ${r.medicineTitle} was declined. You can send a new request.',
            time: r.at,
            target: r.prescriptionId.isEmpty ? null : NotificationTarget.prescriptionDetails,
            targetId: r.prescriptionId.isEmpty ? null : r.prescriptionId,
          ),
      ];
    } catch (_) {
      return const <NotificationItem>[];
    }
  }

  /// Patient: consultation notes and lab results from the last 30 days.
  async.Future<List<NotificationItem>> _recordNotifications() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 30));
      final records = await RecordsService.instance.fetchRecords();
      return [
        for (final r in records)
          if (r.date.isAfter(since))
            NotificationItem(
              id: 'record_${r.id}',
              categoryKey: 'lab_results',
              title: r.type == RecordType.labResult
                  ? 'Lab results available'
                  : 'New consultation notes',
              message: r.type == RecordType.labResult
                  ? '${r.subtitle} is ready to view in Records.'
                  : '${r.subtitle} added notes from your visit. See Records.',
              time: r.date,
            ),
      ];
    } catch (_) {
      return const <NotificationItem>[];
    }
  }

  /// Notification entries built from the refill requests that patients sent
  /// to this doctor and that nobody has answered yet. They disappear once the
  /// doctor approves or declines.
  async.Future<List<NotificationItem>> _refillNotifications() async {
    try {
      final notices = await PrescriptionService.instance.fetchPendingRefillNotices();
      return [
        for (final n in notices)
          NotificationItem(
            id: 'refill_${n.id}',
            categoryKey: 'prescription',
            title: 'Refill requested',
            message: '${n.patientName} asked to refill ${n.medicineTitle}. Tap to review.',
            time: n.requestedAt,
            target: NotificationTarget.doctorPrescriptions,
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