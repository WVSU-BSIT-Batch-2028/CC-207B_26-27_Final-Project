import 'package:flutter/material.dart';

import '../../../../core/constants/contact_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/doctor.dart';
import '../../../../widgets/h360_button.dart';

/// Stage 4 of patient appointment booking.
///
/// Displays the selected doctor's information, appointment schedule,
/// consultation options, consultation fee, reminder option, and clinic
/// contact details. The selected booking details are passed to onBookNow.
class AppointmentDetailsScreen extends StatefulWidget {
  /// Creates the appointment details screen.
  const AppointmentDetailsScreen({
    super.key,
    required this.doctor,
    required this.appointmentDateTime,
    required this.onBookNow,
  });

  /// Doctor selected during Stage 2.
  final Doctor doctor;

  /// Appointment schedule selected during Stage 3.
  final DateTime appointmentDateTime;

  /// Sends the patient's booking choices to the next stage.
  final ValueChanged<AppointmentBookingDetails> onBookNow;

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

/// Stores the patient's consultation and reminder choices.
class AppointmentBookingDetails {
  /// Creates the selected appointment details.
  const AppointmentBookingDetails({
    required this.consultationType,
    required this.reminderEnabled,
  });

  /// Selected consultation type.
  final String consultationType;

  /// Whether the patient wants a one-day-before reminder.
  final bool reminderEnabled;
}

/// Manages the consultation and reminder selections.
class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late String _selectedConsultationType;
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();

    // Use the doctor's available consultation type as the initial choice.
    _selectedConsultationType =
        widget.doctor.consultationType.toLowerCase().contains('video')
            ? 'Video Consultation'
            : 'In-person';
  }

  /// Formats the selected appointment date for display.
  String get _formattedDate {
    return MaterialLocalizations.of(context)
        .formatMediumDate(widget.appointmentDateTime);
  }

  /// Formats the selected appointment time for display.
  String get _formattedTime {
    return TimeOfDay.fromDateTime(widget.appointmentDateTime).format(context);
  }

  /// Passes the selected consultation details to the next booking stage.
  void _bookNow() {
    widget.onBookNow(
      AppointmentBookingDetails(
        consultationType: _selectedConsultationType,
        reminderEnabled: _reminderEnabled,
      ),
    );
  }

  /// Builds the doctor details and booking options.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Doctor Details'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable appointment information.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Doctor profile.
                  Card(
                    color: AppColors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.person_rounded,
                              size: 42,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            widget.doctor.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.doctor.specialty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Demo doctor profile',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Selected appointment schedule.
                  Text(
                    'Appointment Schedule',
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
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Date'),
                          subtitle: Text(_formattedDate),
                        ),
                        Divider(height: 1, color: AppColors.border),
                        ListTile(
                          leading: Icon(
                            Icons.access_time_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Time'),
                          subtitle: Text(_formattedTime),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Consultation type selection.
                  Text(
                    'Consultation Type',
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
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'Video Consultation',
                          groupValue: _selectedConsultationType,
                          activeColor: AppColors.primary,
                          title: const Text('Video Consultation'),
                          secondary: Icon(
                            Icons.videocam_rounded,
                            color: AppColors.primary,
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedConsultationType = value;
                            });
                          },
                        ),
                        Divider(height: 1, color: AppColors.border),
                        RadioListTile<String>(
                          value: 'In-person',
                          groupValue: _selectedConsultationType,
                          activeColor: AppColors.primary,
                          title: const Text('In-person'),
                          secondary: Icon(
                            Icons.local_hospital_rounded,
                            color: AppColors.primary,
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedConsultationType = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Doctor information placeholder.
                  Text(
                    'About',
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
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Doctor profile information will be provided by '
                        'the clinic.',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Consultation fee.
                  Text(
                    'Consultation Fee',
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
                        Icons.payments_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text('Consultation Fee'),
                      trailing: Text(
                        '₱${widget.doctor.consultationFee.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // One-day-before appointment reminder.
                  Text(
                    'Appointment Reminder',
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
                    child: SwitchListTile(
                      value: _reminderEnabled,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Remind me one day before'),
                      subtitle: const Text(
                        'Receive a reminder before your appointment.',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _reminderEnabled = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Clinic contact information.
                  Text(
                    'Contact Clinic',
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
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.phone_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Clinic Phone'),
                          subtitle: SelectableText(ContactInfo.supportPhone),
                        ),
                        Divider(height: 1, color: AppColors.border),
                        ListTile(
                          leading: Icon(
                            Icons.email_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Clinic Email'),
                          subtitle: SelectableText(ContactInfo.supportEmail),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Continue to the appointment confirmation stage.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: H360Button(
                label: 'Book Now',
                expanded: true,
                onPressed: _bookNow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
