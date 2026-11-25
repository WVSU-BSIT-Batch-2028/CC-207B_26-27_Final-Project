import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../screens/doctor/doctor_prescriptions_screen.dart';
import '../screens/patient/prescriptions/prescription_details_screen.dart';
import '../screens/patient/prescriptions/prescription_history_details_screen.dart';
import '../services/prescription_service.dart';

/// Opens the screen a notification points to (nothing happens for a
/// notification with no target). Used by the Home preview and by Profile >
/// Notifications, so a tap behaves the same in both.
///
/// - Doctor refill request: the doctor's Prescriptions screen, where the
///   refill can be approved or declined.
/// - Patient refill answer: the details of that prescription.
Future<void> openNotificationTarget(
  BuildContext context,
  NotificationItem item,
) async {
  final target = item.target;
  if (target == null) return;

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  void say(String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  if (target == NotificationTarget.doctorPrescriptions) {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const DoctorPrescriptionsScreen(),
      ),
    );
    return;
  }

  // Patient: find the prescription, then open it like the list does
  // (details while it is listed as active, read-only history afterwards).
  try {
    final all = await PrescriptionService.instance.fetchPrescriptions();
    final matches = all.where((p) => p.id == item.targetId);
    if (matches.isEmpty) {
      say("We couldn't find that prescription.");
      return;
    }
    final rx = matches.first;
    final Widget page = rx.isListedActiveOn(DateTime.now())
        ? PrescriptionDetailsScreen(prescription: rx)
        : PrescriptionHistoryDetailsScreen(prescription: rx);
    await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  } catch (_) {
    say("We couldn't open that prescription. Please try again.");
  }
}