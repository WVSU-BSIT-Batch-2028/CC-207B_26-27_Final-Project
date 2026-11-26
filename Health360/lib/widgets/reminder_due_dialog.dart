import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/date_format.dart';
import '../services/reminder_scheduler.dart';
import 'dialog_frame.dart';

/// What the patient chose in the reminder popup.
enum ReminderAnswer { taken, later }

/// The "It's time to take" popup shown by the patient shell when
/// ReminderScheduler reports a due medicine.
///
/// Large text and two big choices on purpose (HCI feedback from older
/// users). Returns null if the popup was closed another way.
Future<ReminderAnswer?> showReminderDueDialog(
  BuildContext context,
  DueReminder reminder,
) {
  return showDialog<ReminderAnswer>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => DialogFrame(child: AlertDialog(
      icon: Icon(Icons.alarm_rounded, color: AppColors.primary, size: 44),
      title: const Text("It's time to take", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reminder.title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          Text(
            reminder.instruction,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Reminder for ${formatTime(reminder.dueAt)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(ReminderAnswer.later),
          child: const Text('Remind me in 10 minutes'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(ReminderAnswer.taken),
          child: const Text('Taken'),
        ),
      ],
    )),
  );
}
