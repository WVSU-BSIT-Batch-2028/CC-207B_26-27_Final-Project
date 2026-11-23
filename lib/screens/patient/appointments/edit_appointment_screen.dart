import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/appointment.dart';
import '../../../models/doctor.dart';
import '../../../services/appointment_service.dart';
import '../../../services/booking_doctor_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/state_views.dart';

/// Allows a patient to request changes to an existing appointment.
///
/// The patient can select another doctor, schedule, consultation type,
/// and reminder preference. The original appointment is not updated
/// until the doctor approves the request.
class EditAppointmentScreen extends StatefulWidget {
  /// Creates the appointment editing screen.
  const EditAppointmentScreen({
    super.key,
    required this.appointment,
  });

  /// The original appointment being edited.
  final Appointment appointment;

  @override
  State<EditAppointmentScreen> createState() => _EditAppointmentScreenState();
}

/// Manages the editable appointment details and doctor change request.
class _EditAppointmentScreenState extends State<EditAppointmentScreen> {
  List<Doctor> _doctors = [];
  Doctor? _selectedDoctor;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  late bool _isVideo;
  late bool _reminderEnabled;

  bool _isLoadingDoctors = true;
  bool _isSubmitting = false;
  String? _loadError;
  String? _submitError;

  /// Checks whether the patient still has an available edit request.
  bool get _hasRemainingEditRequests {
    return widget.appointment.editRequestCount <
        AppointmentService.maximumEditRequests;
  }

  /// Loads available doctors and initializes the existing appointment values.
  @override
  void initState() {
    super.initState();

    _selectedDate = DateUtils.dateOnly(widget.appointment.dateTime);
    _selectedTime = TimeOfDay.fromDateTime(widget.appointment.dateTime);
    _isVideo = widget.appointment.isVideo;
    _reminderEnabled = widget.appointment.reminderEnabled;

    _loadDoctors();
  }

  /// Retrieves the doctors available in the booking flow.
  Future<void> _loadDoctors() async {
    setState(() {
      _isLoadingDoctors = true;
      _loadError = null;
    });

    try {
      final doctors = await BookingDoctorService.instance.fetchDoctors();

      if (!mounted) return;

      final matchingDoctor = doctors.where(
        (doctor) =>
            doctor.id == widget.appointment.doctorId ||
            doctor.name == widget.appointment.doctorName,
      );

      setState(() {
        _doctors = doctors;
        _selectedDoctor = matchingDoctor.isNotEmpty
            ? matchingDoctor.first
            : doctors.isNotEmpty
                ? doctors.first
                : null;
        _isLoadingDoctors = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _isLoadingDoctors = false;
      });
    }
  }

  /// Opens the time picker and updates the selected time.
  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selectedTime == null || !mounted) return;

    setState(() {
      _selectedTime = selectedTime;
      _submitError = null;
    });
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

  /// Returns the location based on the selected consultation type.
  String get _appointmentLocation {
    return _isVideo ? 'Google Meet' : 'Health360 Medical Clinic';
  }

  /// Checks whether the selected appointment schedule is in the future.
  bool get _hasValidSchedule {
    return _appointmentDateTime.isAfter(DateTime.now());
  }

  /// Formats the selected appointment date.
  String _formatDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  /// Submits the requested booking changes for doctor approval.
  Future<void> _submitChangeRequest() async {
    if (!_hasRemainingEditRequests) {
      setState(() {
        _submitError =
            'You have reached the maximum of two edit requests for this appointment.';
      });
      return;
    }

    final doctor = _selectedDoctor;

    if (doctor == null) {
      setState(() {
        _submitError = 'Please select a doctor.';
      });
      return;
    }

    if (!_hasValidSchedule) {
      setState(() {
        _submitError = 'Please select a future appointment date and time.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final updatedAppointment =
          await AppointmentService.instance.requestAppointmentChange(
        appointmentId: widget.appointment.id,

        // Firebase UID of the selected doctor.
        doctorId: doctor.id,

        doctorName: doctor.name,
        specialty: doctor.specialty,
        dateTime: _appointmentDateTime,
        location: _appointmentLocation,
        isVideo: _isVideo,
        consultationFee: doctor.consultationFee,
        reminderEnabled: _reminderEnabled,
      );

      if (!mounted) return;

      // Return the appointment containing the pending change request.
      Navigator.of(context).pop(updatedAppointment);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submitError = error.toString();
        _isSubmitting = false;
      });
    }
  }

  /// Builds the doctor selection section.
  Widget _buildDoctorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Doctor',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<Doctor>(
          initialValue: _selectedDoctor,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Doctor',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          items: _doctors.map((doctor) {
            return DropdownMenuItem<Doctor>(
              value: doctor,
              child: Text(
                '${doctor.name} - ${doctor.specialty}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSubmitting
              ? null
              : (doctor) {
                  if (doctor == null) return;

                  setState(() {
                    _selectedDoctor = doctor;
                    _submitError = null;
                  });
                },
        ),
      ],
    );
  }

  /// Builds the date selection section.
  Widget _buildDateSelection() {
    final today = DateUtils.dateOnly(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Date',
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
          child: CalendarDatePicker(
            initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
            firstDate: today,
            lastDate: today.add(const Duration(days: 365)),
            currentDate: today,
            onDateChanged: (date) {
              if (_isSubmitting) return;

              setState(() {
                _selectedDate = DateUtils.dateOnly(date);
                _submitError = null;
              });
            },
          ),
        ),
      ],
    );
  }

  /// Builds the time selection section.
  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            onTap: _isSubmitting ? null : _selectTime,
          ),
        ),
      ],
    );
  }

  /// Builds the consultation type selection section.
  Widget _buildConsultationType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              RadioListTile<bool>(
                value: true,
                groupValue: _isVideo,
                activeColor: AppColors.primary,
                title: const Text('Video Consultation'),
                secondary: Icon(
                  Icons.videocam_rounded,
                  color: AppColors.primary,
                ),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _isVideo = value;
                          _submitError = null;
                        });
                      },
              ),
              Divider(height: 1, color: AppColors.border),
              RadioListTile<bool>(
                value: false,
                groupValue: _isVideo,
                activeColor: AppColors.primary,
                title: const Text('In-person'),
                secondary: Icon(
                  Icons.local_hospital_rounded,
                  color: AppColors.primary,
                ),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _isVideo = value;
                          _submitError = null;
                        });
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the consultation fee and location summary.
  Widget _buildBookingSummary() {
    final doctor = _selectedDoctor;

    if (doctor == null) return const SizedBox.shrink();

    return Card(
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
              Icons.payments_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Consultation Fee'),
            trailing: Text(
              '₱${doctor.consultationFee.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          ListTile(
            leading: Icon(
              _isVideo ? Icons.videocam_rounded : Icons.location_on_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Consultation Location'),
            subtitle: Text(_appointmentLocation),
          ),
        ],
      ),
    );
  }

  /// Builds the appointment reminder option.
  Widget _buildReminderOption() {
    return Card(
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
        onChanged: _isSubmitting
            ? null
            : (value) {
                setState(() {
                  _reminderEnabled = value;
                });
              },
      ),
    );
  }

  /// Builds the editing policy and request allowance information.
  Widget _buildEditPolicyCard() {
    final usedRequests = widget.appointment.editRequestCount;
    final remainingRequests = widget.appointment.remainingEditRequests;
    final maximumRequests = AppointmentService.maximumEditRequests;

    return Card(
      color: AppColors.primary.withValues(alpha: 0.08),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Before You Submit',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You may request changes within 24 hours after your original '
              'booking. You can submit a maximum of $maximumRequests edit '
              'requests per appointment.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Edit requests used: $usedRequests of $maximumRequests',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              'Remaining requests: $remainingRequests',
              style: TextStyle(
                color: remainingRequests > 0
                    ? AppColors.success
                    : AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Every submitted request counts, even if the doctor rejects it. '
              'Your original appointment remains unchanged until approval.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the complete appointment editing screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit Appointment'),
      ),
      body: SafeArea(
        child: _isLoadingDoctors
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorState(
                    message: _loadError!,
                    onRetry: _loadDoctors,
                  )
                : _doctors.isEmpty
                    ? const EmptyState(
                        icon: Icons.medical_services_outlined,
                        title: 'No doctors available',
                        message:
                            'There are currently no doctors available for appointment changes.',
                      )
                    : !_hasRemainingEditRequests
                        ? _buildLimitReachedState()
                        : Column(
                            children: [
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  children: [
                                    _buildEditPolicyCard(),
                                    const SizedBox(height: AppSpacing.lg),

                                    // Existing appointment reference.
                                    Text(
                                      'Current Appointment',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Card(
                                      color: AppColors.surface,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.md),
                                        side: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.event_available_rounded,
                                          color: AppColors.primary,
                                        ),
                                        title: Text(
                                          widget.appointment.doctorName,
                                        ),
                                        subtitle: Text(
                                          '${_formatDate(widget.appointment.dateTime)}'
                                          ' • ${TimeOfDay.fromDateTime(widget.appointment.dateTime).format(context)}',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    _buildDoctorSelection(),
                                    const SizedBox(height: AppSpacing.lg),

                                    _buildDateSelection(),
                                    const SizedBox(height: AppSpacing.lg),

                                    _buildTimeSelection(),
                                    const SizedBox(height: AppSpacing.lg),

                                    _buildConsultationType(),
                                    const SizedBox(height: AppSpacing.lg),

                                    Text(
                                      'Updated Booking Details',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _buildBookingSummary(),
                                    const SizedBox(height: AppSpacing.lg),

                                    Text(
                                      'Appointment Reminder',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _buildReminderOption(),

                                    if (_submitError != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      Text(
                                        _submitError!,
                                        style: TextStyle(
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Submits the requested changes.
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: H360Button(
                                  label: 'Submit Change Request',
                                  expanded: true,
                                  isLoading: _isSubmitting,
                                  onPressed: _isSubmitting
                                      ? null
                                      : _submitChangeRequest,
                                ),
                              ),
                            ],
                          ),
      ),
    );
  }

  /// Displays a message when the patient has used both edit requests.
  Widget _buildLimitReachedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          icon: Icons.edit_off_rounded,
          title: 'Edit Limit Reached',
          message:
              'You have already used both edit requests for this appointment. '
              'You can no longer submit another change request.',
          actionLabel: 'Back to Appointments',
          onAction: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
