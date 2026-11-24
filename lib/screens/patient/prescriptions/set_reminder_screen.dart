import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/prescription.dart';
import '../../../models/reminder_setting.dart';
import '../../../services/browser_notifier.dart';
import '../../../services/prescription_service.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/h360_card.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/dialog_frame.dart';

/// Loading status of the saved reminder.
enum _LoadStatus { loading, ready, error }

/// Lets the patient choose how and when to be reminded to take a medicine.
class SetReminderScreen extends StatefulWidget {
  /// Creates the reminder screen for [prescription].
  const SetReminderScreen({super.key, required this.prescription});

  /// The medicine the reminder is for.
  final Prescription prescription;

  @override
  State<SetReminderScreen> createState() => _SetReminderScreenState();
}

/// Holds the form values and the loading / saving status.
class _SetReminderScreenState extends State<SetReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  _LoadStatus _status = _LoadStatus.loading;
  String _error = '';
  bool _saving = false;

  // Form values
  ReminderMode _mode = ReminderMode.every8Hours;
  DateTime? _startDate;
  TimeOfDay? _customTime;
  bool _notificationsEnabled = true;

  Prescription get _rx => widget.prescription;

  /// Today with no time part.
  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  /// Last day the patient still takes this medicine (endDate is the day after).
  DateTime get _lastDay =>
      DateTime(_rx.endDate.year, _rx.endDate.month, _rx.endDate.day - 1);

  /// True when the treatment is over, so a reminder makes no sense.
  bool get _ended => _lastDay.isBefore(_today);

  /// Load the saved reminder (if any) when the screen opens.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Frees the text controllers when the screen is closed.
  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  /// Loads an existing reminder and pre-fills the form with it.
  /// No saved reminder is not an error: the form just starts with defaults.
  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final saved = await PrescriptionService.instance.fetchReminder(_rx.id);
      if (!mounted) return;

      setState(() {
        if (saved != null) {
          _mode = saved.mode;
          _notificationsEnabled = saved.notificationsEnabled;
          if (saved.customHour != null && saved.customMinute != null) {
            _setCustomTime(
              TimeOfDay(hour: saved.customHour!, minute: saved.customMinute!),
            );
          }
        }
        _setStartDate(_clampDate(saved?.startDate ?? _today));
        _status = _LoadStatus.ready;
      });
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
        _status = _LoadStatus.error;
      });
    }
  }

  /// Keeps [date] inside the range the date picker allows (today .. last day).
  /// showDatePicker crashes if its initial date is outside that range.
  DateTime _clampDate(DateTime date) {
    final day = DateUtils.dateOnly(date);
    if (day.isBefore(_today)) return _today;
    if (day.isAfter(_lastDay)) return _lastDay;
    return day;
  }

  /// Stores the start date and updates the text shown in the field.
  void _setStartDate(DateTime date) {
    _startDate = date;
    _dateController.text = formatLongDate(date);
  }

  /// Stores the custom time and updates the text shown in the field.
  void _setCustomTime(TimeOfDay time) {
    _customTime = time;
    _timeController.text =
        formatTime(DateTime(2000, 1, 1, time.hour, time.minute));
  }

  /// Opens the calendar to choose the start date.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(_startDate ?? _today),
      firstDate: _today,
      lastDate: _lastDay,
    );
    if (picked == null || !mounted) return;
    setState(() => _setStartDate(picked));
  }

  /// Opens the clock to choose the daily reminder time.
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _customTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() => _setCustomTime(picked));
  }

  /// Validates the form, saves the reminder and shows the confirmation.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isCustom = _mode == ReminderMode.customTime;
    final reminder = ReminderSetting(
      prescriptionId: _rx.id,
      mode: _mode,
      startDate: _startDate!,
      notificationsEnabled: _notificationsEnabled,
      customHour: isCustom ? _customTime?.hour : null,
      customMinute: isCustom ? _customTime?.minute : null,
    );

    // Ask the browser for permission during the tap (ignored if already answered).
    if (reminder.notificationsEnabled) BrowserNotifier.requestPermission();

    setState(() => _saving = true);
    try {
      await PrescriptionService.instance.saveReminder(reminder);
      // The scheduler reads the new reminder, so it pops up at the right time.
      await ReminderScheduler.instance.reload();
      if (!mounted) return;
      setState(() => _saving = false);

      await _showSavedDialog(reminder);
      if (!mounted) return;
      Navigator.of(context).pop(); // back to Prescription Details
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(e.message);
    }
  }

  /// Confirmation pop-up (HCI feedback: always confirm that it worked).
  Future<void> _showSavedDialog(ReminderSetting reminder) {
    final message = reminder.notificationsEnabled
        ? 'Reminder is set to ${reminder.summary}.'
        : 'Reminder saved (${reminder.summary}), but notifications are turned off.';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DialogFrame(child: AlertDialog(
                icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        title: const Text('Reminder set'),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      )),
    );
  }

  /// Shows a short message at the bottom of the screen.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Builds the screen: app bar plus the body for the current status.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a Reminder')),
      body: SafeArea(
        // Centred with a max width so it also looks right on a wide window.
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [_buildBody()],
            ),
          ),
        ),
      ),
    );
  }

  /// Skeleton while loading, error with retry, "ended" message, or the form.
  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Column(
          children: [
            SkeletonBox(height: 96, radius: AppRadius.md),
            SizedBox(height: AppSpacing.lg),
            SkeletonBox(height: 120, radius: AppRadius.md),
            SizedBox(height: AppSpacing.lg),
            SkeletonBox(height: 56, radius: AppRadius.md),
            SizedBox(height: AppSpacing.lg),
            SkeletonBox(height: 52, radius: AppRadius.md),
          ],
        );

      case _LoadStatus.error:
        return ErrorState(message: _error, onRetry: _load);

      case _LoadStatus.ready:
        if (_ended) {
          return const EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'This prescription has ended',
            message:
                "Reminders can only be set while you're still taking the medicine.",
          );
        }
        return _buildForm();
    }
  }

  /// The medicine card and the reminder form.
  Widget _buildForm() {
    final textTheme = Theme.of(context).textTheme;
    final headingStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Medicine summary
          _buildMedicineCard(textTheme),
          const SizedBox(height: AppSpacing.lg),

          // Remind me: Every 8 Hours / Custom Time
          Text('Remind me', style: headingStyle),
          const SizedBox(height: AppSpacing.sm),
          Card(
            color: AppColors.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                RadioListTile<ReminderMode>(
                  value: ReminderMode.every8Hours,
                  groupValue: _mode,
                  activeColor: AppColors.primary,
                  title: const Text('Every 8 Hours'),
                  subtitle: const Text('At 8:00 AM, 4:00 PM and 12:00 AM'),
                  onChanged: (value) {
                    if (value != null) setState(() => _mode = value);
                  },
                ),
                Divider(height: 1, color: AppColors.border),
                RadioListTile<ReminderMode>(
                  value: ReminderMode.customTime,
                  groupValue: _mode,
                  activeColor: AppColors.primary,
                  title: const Text('Custom Time'),
                  subtitle: const Text('One reminder a day at a time you pick'),
                  onChanged: (value) {
                    if (value != null) setState(() => _mode = value);
                  },
                ),
              ],
            ),
          ),

          // Time field, only for Custom Time
          if (_mode == ReminderMode.customTime) ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _timeController,
              readOnly: true,
              onTap: _pickTime,
              decoration: AppTheme.inputDecoration(
                label: 'Reminder time',
                hint: 'Choose a time',
              ).copyWith(
                suffixIcon: Icon(
                  Icons.access_time_rounded,
                  color: AppColors.primary,
                ),
              ),
              validator: (value) {
                if (_mode == ReminderMode.customTime &&
                    (value == null || value.isEmpty)) {
                  return 'Choose a reminder time';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // Start date
          Text('Start Date', style: headingStyle),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            decoration: AppTheme.inputDecoration(hint: 'Choose a start date')
                .copyWith(
              suffixIcon: Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Choose a start date'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Enable Notifications
          Card(
            color: AppColors.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: AppColors.border),
            ),
            child: SwitchListTile(
              value: _notificationsEnabled,
              activeThumbColor: AppColors.primary,
              title: const Text('Enable Notifications'),
              subtitle: const Text(
                'A reminder pops up while Health360 is open. In Chrome you can also allow notifications when the tab is in the background.',
              ),
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                // Ask the browser now: it only allows the prompt after a tap.
                if (value) BrowserNotifier.requestPermission();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Save
          H360Button(label: 'Save', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }

  /// Card showing which medicine the reminder is for.
  Widget _buildMedicineCard(TextTheme textTheme) {
    final refill = _rx.refillDate;

    return H360Card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rx.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _rx.instruction,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                if (refill != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Refill ${formatLongDate(refill)}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
