import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/appointment.dart';
import '../../../../models/doctor.dart';
import '../../../../services/appointment_service.dart';
import '../../../../widgets/appointment_status_chip.dart';
import '../../../../widgets/h360_button.dart';
import 'appointment_details_screen.dart';

enum _ConfirmationState { loading, success, error }

/// Stage 5 of patient appointment booking.
///
/// Submits the booking through AppointmentService and displays
/// the saved appointment details after successful submission.
class AppointmentConfirmationScreen extends StatefulWidget {
  const AppointmentConfirmationScreen({
    super.key,
    required this.doctor,
    required this.appointmentDateTime,
    required this.bookingDetails,
    required this.onDone,
  });

  final Doctor doctor;
  final DateTime appointmentDateTime;
  final AppointmentBookingDetails bookingDetails;
  final VoidCallback onDone;

  @override
  State<AppointmentConfirmationScreen> createState() =>
      _AppointmentConfirmationScreenState();
}

class _AppointmentConfirmationScreenState
    extends State<AppointmentConfirmationScreen> {
  _ConfirmationState _state = _ConfirmationState.loading;

  Appointment? _appointment;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _submitBooking();
  }

  /// Saves the appointment using the appointment service.
  Future<void> _submitBooking() async {
    if (_state == _ConfirmationState.success ||
        (_state == _ConfirmationState.loading && _appointment != null)) {
      return;
    }

    setState(() {
      _state = _ConfirmationState.loading;
      _errorMessage = '';
    });

    try {
      final isVideo = widget.bookingDetails.consultationType
          .toLowerCase()
          .contains('video');

      final location = isVideo ? 'Google Meet' : 'Health360 Medical Clinic';

      final appointment = await AppointmentService.instance.createAppointment(
        title: 'Consultation with ${widget.doctor.name}',
        doctorId: widget.doctor.id,
        doctorName: widget.doctor.name,
        specialty: widget.doctor.specialty,
        dateTime: widget.appointmentDateTime,
        location: location,
        isVideo: isVideo,
        consultationFee: widget.doctor.consultationFee.toDouble(),
        reminderEnabled: widget.bookingDetails.reminderEnabled,
      );

      if (!mounted) return;

      setState(() {
        _appointment = appointment;
        _state = _ConfirmationState.success;
      });
    } on AppointmentException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
        _state = _ConfirmationState.error;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong while submitting your booking.';
        _state = _ConfirmationState.error;
      });
    }
  }

  String _formatDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatTime(DateTime date) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent leaving while the booking is being submitted.
      // Allow navigation after success or failure.
      canPop: _state != _ConfirmationState.loading,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _state == _ConfirmationState.loading
                ? null
                : () => Navigator.of(context).pop(),
          ),
          title: const Text('Appointment Confirmation'),
        ),
        body: SafeArea(
          child: switch (_state) {
            _ConfirmationState.loading => _buildLoading(),
            _ConfirmationState.error => _buildError(),
            _ConfirmationState.success => _buildSuccess(),
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Submitting your appointment...',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Please wait while we process your booking.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Booking Unsuccessful',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage,
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            H360Button(
              label: 'Try Again',
              expanded: true,
              onPressed: _submitBooking,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final appointment = _appointment!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const SizedBox(height: AppSpacing.md),
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 76,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Booking Request Submitted!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your appointment request has been submitted. '
                'Please wait for the doctor to confirm your schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Booking status and reference number.
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Booking Status',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          AppointmentStatusChip(
                            status: appointment.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Appointment Reference',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(
                        appointment.id,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Appointment information.
              Text(
                'Appointment Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
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
                    _detailTile(
                      icon: Icons.person_rounded,
                      label: 'Doctor',
                      value: appointment.doctorName,
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: Icons.medical_services_rounded,
                      label: 'Specialty',
                      value: appointment.specialty,
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: Icons.calendar_month_rounded,
                      label: 'Date',
                      value: _formatDate(appointment.dateTime),
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: _formatTime(appointment.dateTime),
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: appointment.isVideo
                          ? Icons.videocam_rounded
                          : Icons.location_on_rounded,
                      label: 'Consultation Type',
                      value: appointment.isVideo
                          ? 'Video Consultation'
                          : 'In-person',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      value: appointment.location,
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: Icons.payments_rounded,
                      label: 'Consultation Fee',
                      value: appointment.consultationFee != null
                          ? '₱${appointment.consultationFee!.toStringAsFixed(2)}'
                          : 'Not specified',
                    ),
                    Divider(height: 1, color: AppColors.border),
                    _detailTile(
                      icon: Icons.notifications_active_rounded,
                      label: 'One-day Reminder',
                      value:
                          appointment.reminderEnabled ? 'Enabled' : 'Disabled',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Note: Your appointment is not yet confirmed. '
                'You can check its status in My Appointments.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Return to the Appointments Overview.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: H360Button(
            label: 'Done',
            expanded: true,
            onPressed: widget.onDone,
          ),
        ),
      ],
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
