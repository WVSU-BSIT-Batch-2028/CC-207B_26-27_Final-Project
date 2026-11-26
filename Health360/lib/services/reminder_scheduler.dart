import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/prescription.dart';
import '../models/reminder_setting.dart';
import 'browser_notifier.dart';
import 'prescription_service.dart';

/// One medicine that is due now, shown in the "It's time to take" popup.
class DueReminder {
  const DueReminder({
    required this.prescriptionId,
    required this.title,
    required this.instruction,
    required this.dueAt,
  });

  final String prescriptionId;

  /// e.g. "Cetirizine 5mg"
  final String title;

  /// e.g. "Take 1 tablet - 1x a day"
  final String instruction;

  /// When it was due (or when the snooze ended).
  final DateTime dueAt;
}

/// Checks the patient's saved reminders while the patient side is open, and
/// reports each one when it is due.
///
/// HOW IT WORKS
/// - [start] loads the reminders and prescriptions once, then a timer checks
///   every 30 seconds. No Firestore reads happen during the checks.
/// - A reminder is due at the times from `ReminderSetting.timesOn` (custom
///   time, or 12:00 AM / 8:00 AM / 4:00 PM for "every 8 hours"). It is shown
///   once, up to 15 minutes late (e.g. if the laptop was asleep).
/// - It is skipped when notifications are off, the prescription has not
///   started yet or has ended,
///   or (daily reminders) the dose was already marked as taken today.
/// - "Remind me in 10 minutes" calls [snooze].
/// - If the browser tab is in the background and the patient allowed it, a
///   browser notification is shown too (BrowserNotifier).
///
/// LIMITATION: the app must be open (a tab is enough). Reminders while it is
/// closed would need push notifications from a server (future work).
class ReminderScheduler {
  ReminderScheduler._();
  static final ReminderScheduler instance = ReminderScheduler._();

  static const Duration _checkEvery = Duration(seconds: 30);
  static const Duration _lateWindow = Duration(minutes: 15);
  static const Duration snoozeFor = Duration(minutes: 10);

  Timer? _timer;

  /// Whoever started the scheduler (the patient shell). Only that owner can
  /// stop it, so a new shell is not stopped by the old one closing.
  Object? _owner;
  void Function(DueReminder reminder)? _onDue;

  List<ReminderSetting> _reminders = const [];
  Map<String, Prescription> _prescriptions = const {};

  /// Reminders already shown ("<prescription id>@<due time>").
  final Set<String> _shown = {};

  /// Snoozed reminders: prescription id -> when to show again.
  final Map<String, DateTime> _snoozed = {};

  /// Starts checking. [onDue] shows the popup.
  Future<void> start(Object owner, void Function(DueReminder reminder) onDue) async {
    _owner = owner;
    _onDue = onDue;
    await reload();
    _timer?.cancel();
    _timer = Timer.periodic(_checkEvery, (_) => _check());
    _check();
  }

  /// Stops checking (the patient side closed or the patient logged out).
  void stop(Object owner) {
    if (!identical(owner, _owner)) return;
    _timer?.cancel();
    _timer = null;
    _owner = null;
    _onDue = null;
    _reminders = const [];
    _prescriptions = const {};
    _snoozed.clear();
  }

  /// Reads the reminders and prescriptions again (after a reminder is saved).
  /// If they cannot be loaded, the previous ones are kept.
  Future<void> reload() async {
    try {
      final results = await Future.wait<Object>([
        PrescriptionService.instance.fetchAllReminders(),
        PrescriptionService.instance.fetchPrescriptions(),
      ]);
      _reminders = results[0] as List<ReminderSetting>;
      _prescriptions = {
        for (final p in results[1] as List<Prescription>) p.id: p,
      };
    } on PrescriptionException catch (e) {
      debugPrint('Reminders not loaded: ${e.message}');
    }
  }

  /// "Remind me in 10 minutes".
  void snooze(DueReminder reminder) {
    _snoozed[reminder.prescriptionId] = DateTime.now().add(snoozeFor);
  }

  /// Runs every 30 seconds: shows what is due now.
  Future<void> _check() async {
    final now = DateTime.now();

    // Snoozed reminders whose 10 minutes are over.
    for (final entry in Map.of(_snoozed).entries) {
      if (now.isBefore(entry.value)) continue;
      _snoozed.remove(entry.key);
      final p = _prescriptions[entry.key];
      if (p != null) _show(p, entry.value);
    }

    for (final reminder in _reminders) {
      if (!reminder.notificationsEnabled) continue;
      final p = _prescriptions[reminder.prescriptionId];
      // No reminders before the medicine starts or after it ends.
      if (p == null || !p.hasStartedOn(now) || !p.isActiveOn(now)) continue;

      for (final dueAt in reminder.timesOn(now)) {
        final key = '${p.id}@${dueAt.toIso8601String()}';
        final late = now.difference(dueAt);
        if (late.isNegative || late > _lateWindow || _shown.contains(key)) continue;
        _shown.add(key);

        // A once-a-day reminder is not needed if today's dose is marked taken.
        if (reminder.mode == ReminderMode.customTime && await _takenToday(p.id)) continue;
        _show(p, dueAt);
      }
    }
  }

  Future<bool> _takenToday(String prescriptionId) async {
    try {
      return (await PrescriptionService.instance.fetchActivity(prescriptionId)).takenToday;
    } on PrescriptionException {
      return false; // when unsure, remind
    }
  }

  void _show(Prescription p, DateTime dueAt) {
    final reminder = DueReminder(
      prescriptionId: p.id,
      title: p.title,
      instruction: p.instruction,
      dueAt: dueAt,
    );

    // Browser notification only when the tab is in the background; when it
    // is in front, the in-app popup is enough.
    if (BrowserNotifier.pageHidden) {
      BrowserNotifier.show("It's time to take ${p.title}", p.instruction);
    }
    _onDue?.call(reminder);
  }
}
