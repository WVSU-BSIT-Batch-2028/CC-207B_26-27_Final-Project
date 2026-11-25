import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/date_format.dart';
import '../models/appointment.dart';
import '../models/appointment_status.dart';
import '../models/doctor_dashboard_data.dart';
import '../models/prescription.dart';
import '../models/refill_notice.dart';
import 'appointment_service.dart';
import 'booking_doctor_service.dart';
import 'dashboard_service.dart';
import 'doctor_overview.dart';
import 'prescription_mapper.dart';
import 'prescription_service.dart';

/// Loads the doctor Home and Dashboard from Firestore: today's schedule,
/// the Quick Overview numbers ([DoctorOverview]) and recent activity.
/// Follows the demo switch; every failure becomes a [DashboardException].
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
        db.collection('prescriptions').where('doctorId', isEqualTo: user.uid).get(),
        db.collection('labResults').where('doctorId', isEqualTo: user.uid).get(),
        _pendingRefills(),
        db.collection('users').doc(user.uid).get(),
      ]);

      final appointments = results[0] as List<Appointment>;
      final prescriptionDocs = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final labDocs = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final refills = results[3] as List<RefillNotice>;
      final account = results[4] as DocumentSnapshot<Map<String, dynamic>>;

      final now = DateTime.now();
      final today = appointments
          .where((a) =>
              _sameDay(a.dateTime, now) && a.status != AppointmentStatus.cancelled)
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Next up: the next patient still to be seen.
      final next = today
          .where((a) =>
              a.dateTime.isAfter(now) &&
              (a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.confirmed))
          .toList();

      final overview = DoctorOverview.compute(
        appointments: appointments,
        prescriptions: [
          for (final doc in prescriptionDocs.docs)
            if (_prescriptionOf(doc) case final p?)
              (patientId: (doc.data()['patientId'] as String?) ?? '', prescription: p),
        ],
        labResultDates: [
          for (final doc in labDocs.docs)
            (date: _dateOf(doc.data()['date']), enteredAt: _dateOf(doc.data()['createdAt'])),
        ],
        now: now,
      );

      final name = (account.data()?['fullName'] as String?)?.trim() ?? '';
      final doctor = BookingDoctorService.instance.doctorFrom(
        user.uid,
        account.data() ?? const <String, dynamic>{},
      );

      return DoctorDashboardData(
        doctorShortName: _shortName(name),
        specialty: doctor.specialty,
        todayAppointments: overview.todayAppointments,
        patients: overview.activePatients,
        prescriptions: overview.activePrescriptions,
        labResults: overview.todayLabResults,
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

  /// Emits when the doctor's appointments, prescriptions or lab results
  /// change, so Home can reload by itself. Each query's first snapshot
  /// (the current data) is skipped.
  Stream<void> watchChanges() {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream<void>.empty();

    final db = FirebaseFirestore.instance;
    final queries = [
      for (final name in ['appointments', 'prescriptions', 'labResults'])
        db.collection(name).where('doctorId', isEqualTo: user.uid),
    ];

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        for (final query in queries) {
          var first = true;
          subs.add(query.snapshots().listen(
            (_) {
              if (first) {
                first = false;
                return;
              }
              controller.add(null);
            },
            onError: (Object e) => debugPrint('Doctor live update stopped: $e'),
          ));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }

  /// The prescription in [doc], or null when the document is damaged.
  Prescription? _prescriptionOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return prescriptionFromData(doc.id, doc.data());
    } on FormatException {
      return null;
    }
  }

  /// A Firestore Timestamp as a DateTime, or null.
  DateTime? _dateOf(Object? value) => value is Timestamp ? value.toDate() : null;

  /// Pending refill requests, or none if they cannot be read.
  Future<List<RefillNotice>> _pendingRefills() async {
    try {
      return await PrescriptionService.instance.fetchPendingRefillNotices();
    } on PrescriptionException {
      return const <RefillNotice>[];
    }
  }

  /// Newest first, at most five: refill requests, new bookings and change
  /// requests waiting for this doctor.
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
