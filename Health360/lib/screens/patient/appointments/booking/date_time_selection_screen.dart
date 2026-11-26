import 'package:flutter/material.dart';

import '../../../../core/constants/clinic_hours.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/doctor.dart';
import '../../../../widgets/h360_button.dart';

/// Stage 3 of patient appointment booking.
///
/// Displays the selected doctor and allows the patient to choose
/// an appointment date and time. The selected DateTime is passed
/// to the next booking stage through onNext.
class DateTimeSelectionScreen extends StatefulWidget {
  /// Creates the date and time selection screen.
  const DateTimeSelectionScreen({
    super.key,
    required this.doctor,
    required this.onNext,
  });

  /// Doctor selected during Stage 2.
  final Doctor doctor;

  /// Passes the selected appointment date and time to the next stage.
  final ValueChanged<DateTime> onNext;

  @override
  State<DateTimeSelectionScreen> createState() =>
      _DateTimeSelectionScreenState();
}

/// Manages the patient's selected appointment date and time.
class _DateTimeSelectionScreenState extends State<DateTimeSelectionScreen> {
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();

    // Start with tomorrow (or the next open day) as the suggested date.
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = ClinicHours.nextOpenDay(tomorrow);
  }

  /// Opens the time picker and updates the selected time.
  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selectedTime == null || !mounted) return;

    // Only clinic hours can be chosen (8:00 AM to 4:30 PM).
    final picked = DateTime(2000, 1, 3, selectedTime.hour, selectedTime.minute); // a Monday
    if (!ClinicHours.isWithinHours(picked)) {
      _showError('Please choose a time from 8:00 AM to 4:30 PM.');
      return;
    }

    setState(() {
      _selectedTime = selectedTime;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Combines the selected date and time into one DateTime value.
  DateTime get _appointmentDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  /// Passes the selected schedule to the next booking stage.
  /// Stops here with a message if the time is in the past or outside
  /// clinic hours (e.g. 9:00 AM today when it is already 10:00 AM).
  void _confirmSelection() {
    final error = ClinicHours.validate(_appointmentDateTime);
    if (error != null) {
      _showError(error);
      return;
    }
    widget.onNext(_appointmentDateTime);
  }

  /// Builds the date and time selection screen.
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Select Date & Time'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar and time selection.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Selected doctor information.
                  Text(
                    'Selected Doctor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    color: AppColors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        widget.doctor.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(widget.doctor.specialty),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Calendar heading.
                  Text(
                    'Choose a Date',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Calendar with selectable dates and month navigation.
                  Card(
                    color: AppColors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 365)),
                      currentDate: today,
                      // Sundays are greyed out (clinic closed).
                      selectableDayPredicate: ClinicHours.isOpenDay,
                      onDateChanged: (date) {
                        setState(() {
                          _selectedDate = DateUtils.dateOnly(date);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Time selection field.
                  Text(
                    'Choose a Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    color: AppColors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.access_time_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text('Selected Time'),
                      subtitle: Text(_selectedTime.format(context)),
                      trailing: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                      onTap: _selectTime,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Clinic hours: ${ClinicHours.description}.',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Continue after choosing a date and time.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: H360Button(
                label: 'Confirm',
                expanded: true,
                onPressed: _confirmSelection,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
