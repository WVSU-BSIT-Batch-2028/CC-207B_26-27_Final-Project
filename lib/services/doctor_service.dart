import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/date_format.dart';
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/doctor_dashboard_data.dart';
import '../models/refill_notice.dart';
import 'appointment_service.dart';
import 'booking_doctor_service.dart';
import 'dashboard_service.dart';
import 'prescription_service.dart';

/// Loads the doctor Home and Dashboard from Firestore.
///
/// - Today's schedule and the patient count: the doctor's own appointments
///   (AppointmentService, `appointments` where doctorId == uid).
/// - Prescriptions and lab results: how many this doctor wrote
///   (`count()` queries, which cost 1 read per 1,000 documents).
/// - Recent activity: refill requests waiting for an answer, and new
///   bookings or change requests waiting for the doctor.
///
/// Uses the same demo switch as the patient Home (long-press the avatar)
/// so loading / empty / error can still be shown in the presentation.
/// Every failure becomes a [DashboardException], so the screens keep their
/// normal error state with "Try again".
class DoctorService {
  DoctorService._();
  static final DoctorService instance = DoctorService._();

  /// Used when the doctor's specialty is not known (e.g. no Firebase).
  static const String specialty = 'General Practitioner';

  /// How many of today's appointments Home lists.
  static const int _shownToday = 4;

  Future<DoctorDashboardData> fetchDashboard() async {
    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const DashboardException(
          "We couldn't load your schedule. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const DoctorDashboardData(
          doctorShortName: 'Doctor',
          specialty: specialty,
          todayAppointments: 0,
          patients: 0,
          prescriptions: 0,
          labResults: 0,
          nextUp: null,
          appointments: [],
          activities: [],
        );
      case DemoScenario.normal:
        return _load();
    }
  }

  Future<DoctorDashboardData> _load() async {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const DashboardException('Please sign in again to see your schedule.');
    }

    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait<Object?>([
        AppointmentService.instance.fetchAppointments(),
        _count(db.collection('prescriptions').where('doctorId', isEqualTo: user.uid)),
        _count(db.collection('labResults').where('doctorId', isEqualTo: user.uid)),
        _pendingRefills(),
        db.collection('users').doc(user.uid).get(),
      ]);

      final appointments = results[0] as List<Appointment>;
      final prescriptions = results[1] as int;
      final labResults = results[2] as int;
      final refills = results[3] as List<RefillNotice>;
      final account = results[4] as DocumentSnapshot<Map<String, dynamic>>;

      final now = DateTime.now();
      final today = appointments
          .where((a) =>
              _sameDay(a.dateTime, now) && a.status != AppointmentStatus.cancelled)
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      final next = today.where((a) => a.dateTime.isAfter(now)).toList();

      // Patients = everyone with a booking that was not cancelled.
      final patients = {
        for (final a in appointments)
          if (a.status != AppointmentStatus.cancelled && (a.patientId ?? '').isNotEmpty)
            a.patientId!,
      };

      final name = (account.data()?['fullName'] as String?)?.trim() ?? '';
      final doctor = BookingDoctorService.instance.doctorFrom(
        user.uid,
        account.data() ?? const <String, dynamic>{},
      );

      return DoctorDashboardData(
        doctorShortName: _shortName(name),
        specialty: doctor.specialty,
        todayAppointments: today.length,
        patients: patients.length,
        prescriptions: prescriptions,
        labResults: labResults,
        nextUp: next.isEmpty
            ? null
            : '${formatTime(next.first.dateTime)} · ${next.first.patientName ?? 'Patient'}',
        appointments: [
          for (final a in today.take(_shownToday))
            DoctorAppointment(
              id: a.id,
              time: formatTime(a.dateTime),
              patientName: a.patientName ?? 'Patient',
              reason: a.specialty,
              isVideo: a.isVideo,
              status: a.status,
            ),
        ],
        activities: _activities(appointments, refills, now),
      );
    } on DashboardException {
      rethrow;
    } on AppointmentException catch (e) {
      throw DashboardException(e.message);
    } on FirebaseException catch (e) {
      debugPrint('Doctor dashboard error: ${e.code} ${e.message}');
      throw const DashboardException(
        "We couldn't load your schedule. Check your connection and try again.",
      );
    }
  }

  /// Number of documents a query matches, without downloading them.
  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  /// Pending refill requests, or none if they cannot be read (the rest of
  /// the dashboard still loads).
  Future<List<RefillNotice>> _pendingRefills() async {
    try {
      return await PrescriptionService.instance.fetchPendingRefillNotices();
    } on PrescriptionException {
      return const <RefillNotice>[];
    }
  }

  /// Newest first: refill requests, new bookings and change requests that
  /// are waiting for this doctor. At most five rows.
  List<ActivityItem> _activities(
    List<Appointment> appointments,
    List<RefillNotice> refills,
    DateTime now,
  ) {
    final rows = <({DateTime at, ActivityItem item})>[
      for (final r in refills)
        (
          at: r.requestedAt,
          item: ActivityItem(
            type: ActivityType.prescription,
            title: 'Refill request',
            subtitle: '${r.patientName}: ${r.medicineTitle}',
            time: formatActivityTime(r.requestedAt, now: now),
          ),
        ),
      for (final a in appointments)
        if (a.dateTime.isAfter(now) && a.status == AppointmentStatus.pending)
          (
            at: a.bookedAt ?? a.dateTime,
            item: ActivityItem(
              type: ActivityType.message,
              title: 'New booking to confirm',
              subtitle: 'Patient: ${a.patientName ?? 'Patient'}',
              time: formatActivityTime(a.bookedAt ?? a.dateTime, now: now),
            ),
          )
        else if (a.changeRequest?.status == ChangeRequestStatus.pending)
          (
            at: a.changeRequest!.requestedAt,
            item: ActivityItem(
              type: ActivityType.message,
              title: 'Change request',
              subtitle: 'Patient: ${a.patientName ?? 'Patient'}',
              time: formatActivityTime(a.changeRequest!.requestedAt, now: now),
            ),
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return [for (final row in rows.take(5)) row.item];
  }

  /// "Dr. Andrea Santos" or "Andrea Santos" -> "Dr. Santos".
  String _shortName(String fullName) {
    final clean = fullName
        .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
        .trim();
    if (clean.isEmpty) return 'Doctor';
    return 'Dr. ${clean.split(RegExp(r'\s+')).last}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
