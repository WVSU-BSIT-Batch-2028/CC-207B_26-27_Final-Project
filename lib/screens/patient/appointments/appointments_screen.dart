import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/appointment.dart';
import '../../../models/appointment_status.dart';
import '../../../services/appointment_service.dart';
import '../../../widgets/appointment_status_chip.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/h360_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/state_views.dart';
import 'edit_appointment_screen.dart';

enum _LoadStatus { loading, ready, error }

enum _AppointmentFilter { upcoming, past }

/// Patient Appointments Overview.
///
/// Displays upcoming and past appointments, their statuses, and available
/// patient actions. Appointment data is retrieved through AppointmentService.
class AppointmentsScreen extends StatefulWidget {
  /// Creates the patient appointments screen.
  const AppointmentsScreen({
    super.key,
    required this.onBookAppointment,
    required this.onJoinConsultation,
  });

  /// Called when the patient taps Book Appointment.
  final VoidCallback onBookAppointment;

  /// Called when the patient opens a video consultation.
  final ValueChanged<Appointment> onJoinConsultation;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

/// Manages appointment loading, filtering, editing, and cancellation.
class _AppointmentsScreenState extends State<AppointmentsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  _AppointmentFilter _filter = _AppointmentFilter.upcoming;

  List<Appointment> _appointments = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  /// Loads appointments from the appointment service.
  Future<void> _loadAppointments({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _status = _LoadStatus.loading);
    }

    try {
      final appointments =
          await AppointmentService.instance.fetchAppointments();

      if (!mounted) return;

      setState(() {
        _appointments = appointments;
        _status = _LoadStatus.ready;
        _error = '';
      });
    } on AppointmentException catch (e) {
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

  /// Changes the selected appointment filter.
  void _changeFilter(_AppointmentFilter filter) {
    setState(() => _filter = filter);
  }

  /// Checks whether the appointment is still within its management period.
  ///
  /// The period starts from the original booking timestamp, not the
  /// appointment date. The appointment must also be upcoming and active.
  bool _isWithinManagementWindow(Appointment appointment) {
    final now = DateTime.now();
    final bookedAt = appointment.bookedAt;

    if (appointment.dateTime.isBefore(now) ||
        appointment.status == AppointmentStatus.cancelled ||
        appointment.outcome != AppointmentOutcome.none ||
        bookedAt == null) {
      return false;
    }

    final elapsed = now.difference(bookedAt);

    return !elapsed.isNegative &&
        elapsed <= AppointmentService.changeRequestWindow;
  }

  /// Checks whether the patient can submit another edit request.
  ///
  /// Editing is unavailable when a request is pending or the two-request
  /// limit has already been reached.
  bool _canEditAppointment(Appointment appointment) {
    return _isWithinManagementWindow(appointment) &&
        appointment.changeRequest?.status != ChangeRequestStatus.pending &&
        appointment.editRequestCount < AppointmentService.maximumEditRequests;
  }

  /// Checks whether the patient can cancel the appointment.
  ///
  /// Cancellation is separate from the edit-request limit. It does not
  /// consume an edit request and can still be performed when an edit request
  /// is pending.
  bool _canCancelAppointment(Appointment appointment) {
    return _isWithinManagementWindow(appointment);
  }

  /// Returns appointments based on the selected Upcoming or Past filter.
  List<Appointment> _filteredAppointments() {
    final now = DateTime.now();

    final filtered = _appointments.where((appointment) {
      if (_filter == _AppointmentFilter.upcoming) {
        return !appointment.dateTime.isBefore(now);
      }

      return appointment.dateTime.isBefore(now);
    }).toList();

    filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (_filter == _AppointmentFilter.past) {
      return filtered.reversed.toList();
    }

    return filtered;
  }

  /// Formats the appointment date for display.
  String _formatDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  /// Formats the appointment time for display.
  String _formatTime(DateTime date) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
  }

  /// Opens the appointment editing screen and refreshes the list afterward.
  Future<void> _editAppointment(Appointment appointment) async {
    if (!_canEditAppointment(appointment)) return;

    final result = await Navigator.of(context).push<Appointment>(
      MaterialPageRoute(
        builder: (_) => EditAppointmentScreen(
          appointment: appointment,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await _loadAppointments(showLoading: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your change request has been submitted for doctor approval.',
          ),
        ),
      );
    }
  }

  /// Asks the patient to confirm cancellation before cancelling the booking.
  Future<void> _confirmCancellation(Appointment appointment) async {
    if (!_canCancelAppointment(appointment)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Appointment?'),
          content: Text(
            'Are you sure you want to cancel your appointment with '
            '${appointment.doctorName}? This action will take effect immediately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Appointment'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel Appointment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await AppointmentService.instance.cancelPatientAppointment(
        appointment.id,
      );

      if (!mounted) return;

      await _loadAppointments(showLoading: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your appointment has been cancelled.'),
        ),
      );
    } on AppointmentException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to cancel the appointment. Please try again.'),
        ),
      );
    }
  }

  /// Opens the centered appointment details dialog.
  void _showAppointmentDetails(Appointment appointment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _PatientAppointmentDetailsDialog(
          appointment: appointment,
          date: _formatDate(appointment.dateTime),
          time: _formatTime(appointment.dateTime),
          canEdit: _canEditAppointment(appointment),
          canCancel: _canCancelAppointment(appointment),
          onEdit: () {
            Navigator.pop(dialogContext);
            _editAppointment(appointment);
          },
          onCancel: () {
            Navigator.pop(dialogContext);
            _confirmCancellation(appointment);
          },
        );
      },
    );
  }

  /// Builds the screen's main content.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadAppointments(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Appointments',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manage your consultations and schedules.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            H360Button(
              label: 'Book Appointment',
              icon: Icons.add_rounded,
              onPressed: widget.onBookAppointment,
            ),
            const SectionHeader(
              title: 'My Appointments',
              subtitle: 'View and manage your consultation schedules.',
            ),
            _buildFilters(),
            const SizedBox(height: AppSpacing.md),
            _buildAppointmentContent(),
          ],
        ),
      ),
    );
  }

  /// Builds the Upcoming and Past filter buttons.
  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: _filterButton(
            label: 'Upcoming',
            filter: _AppointmentFilter.upcoming,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _filterButton(
            label: 'Past',
            filter: _AppointmentFilter.past,
          ),
        ),
      ],
    );
  }

  /// Builds one appointment filter button.
  Widget _filterButton({
    required String label,
    required _AppointmentFilter filter,
  }) {
    final selected = _filter == filter;

    return OutlinedButton(
      onPressed: () => _changeFilter(filter),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.brandNavy : AppColors.surface,
        foregroundColor: selected ? Colors.white : AppColors.navy,
        side: BorderSide(
          color: selected ? AppColors.brandNavy : AppColors.border,
        ),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Displays the appropriate loading, error, empty, or ready state.
  Widget _buildAppointmentContent() {
    switch (_status) {
      case _LoadStatus.loading:
        return _buildLoadingState();

      case _LoadStatus.error:
        return ErrorState(
          message: _error,
          onRetry: _loadAppointments,
        );

      case _LoadStatus.ready:
        final appointments = _filteredAppointments();

        if (appointments.isEmpty) {
          return EmptyState(
            icon: Icons.event_available_rounded,
            title: _filter == _AppointmentFilter.upcoming
                ? 'No upcoming appointments'
                : 'No past appointments',
            message: _filter == _AppointmentFilter.upcoming
                ? 'You do not have any scheduled consultations yet. Book an appointment to get started.'
                : 'Your completed or previous consultations will appear here.',
            actionLabel: _filter == _AppointmentFilter.upcoming
                ? 'Book Appointment'
                : null,
            onAction: _filter == _AppointmentFilter.upcoming
                ? widget.onBookAppointment
                : null,
          );
        }

        return Column(
          children: [
            for (final appointment in appointments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AppointmentCard(
                  appointment: appointment,
                  date: _formatDate(appointment.dateTime),
                  time: _formatTime(appointment.dateTime),
                  onViewDetails: () => _showAppointmentDetails(appointment),
                  onJoinConsultation: appointment.isVideo
                      ? () => widget.onJoinConsultation(appointment)
                      : null,
                ),
              ),
          ],
        );
    }
  }

  /// Builds placeholder cards while appointment data is loading.
  Widget _buildLoadingState() {
    return const Column(
      children: [
        SkeletonBox(height: 130, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 130, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 130, radius: AppRadius.md),
      ],
    );
  }
}

/// Displays one appointment using the patient-side appointment card layout.
class _AppointmentCard extends StatelessWidget {
  /// Creates an appointment card.
  const _AppointmentCard({
    required this.appointment,
    required this.date,
    required this.time,
    required this.onViewDetails,
    required this.onJoinConsultation,
  });

  final Appointment appointment;
  final String date;
  final String time;
  final VoidCallback onViewDetails;
  final VoidCallback? onJoinConsultation;

  /// Builds the appointment card.
  @override
  Widget build(BuildContext context) {
    final changeRequest = appointment.changeRequest;
    final patientName = appointment.patientName?.trim().isNotEmpty == true
        ? appointment.patientName!
        : 'Patient';

    final fee = appointment.consultationFee != null
        ? '₱${appointment.consultationFee!.toStringAsFixed(2)}'
        : 'Not specified';

    return H360Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient name, doctor name, and appointment status.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.doctorName,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              AppointmentStatusChip(status: appointment.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Consultation title and specialty.
          Text(
            appointment.title,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            appointment.specialty,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Appointment date, time, and location.
          _AppointmentInfoRow(
            icon: Icons.calendar_month_rounded,
            text: date,
          ),
          const SizedBox(height: AppSpacing.xs),
          _AppointmentInfoRow(
            icon: Icons.access_time_rounded,
            text: time,
          ),
          const SizedBox(height: AppSpacing.xs),
          _AppointmentInfoRow(
            icon: Icons.location_on_outlined,
            text: appointment.location,
          ),

          // Shows the current state of the patient's change request.
          if (changeRequest != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ChangeRequestStatusText(status: changeRequest.status),
          ],

          if (changeRequest?.status == ChangeRequestStatus.pending &&
              appointment.dateTime.isAfter(DateTime.now()) &&
              appointment.status != AppointmentStatus.cancelled) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your change request is awaiting doctor approval.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Consultation fee and View Details action.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fee: $fee',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewDetails,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Video consultation action remains on the appointment card.
          if (appointment.isVideo) ...[
            const SizedBox(height: AppSpacing.xs),
            if (appointment.status == AppointmentStatus.pending)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Your consultation is waiting for confirmation.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            if (appointment.status == AppointmentStatus.cancelled)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'This appointment has been cancelled.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onJoinConsultation,
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('View Video Consultation'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Displays an icon and a short appointment detail.
class _AppointmentInfoRow extends StatelessWidget {
  /// Creates an appointment information row.
  const _AppointmentInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  /// Builds the information row.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays the status of an appointment change request.
class _ChangeRequestStatusText extends StatelessWidget {
  /// Creates a change-request status label.
  const _ChangeRequestStatusText({required this.status});

  final ChangeRequestStatus status;

  /// Builds the status label with a matching color and message.
  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    switch (status) {
      case ChangeRequestStatus.pending:
        label = 'Change request pending approval';
        color = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
      case ChangeRequestStatus.approved:
        label = 'Change request approved';
        color = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
      case ChangeRequestStatus.rejected:
        label = 'Change request rejected';
        color = AppColors.danger;
        icon = Icons.cancel_outlined;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays complete appointment information in a centered dialog.
class _PatientAppointmentDetailsDialog extends StatelessWidget {
  /// Creates the patient appointment details dialog.
  const _PatientAppointmentDetailsDialog({
    required this.appointment,
    required this.date,
    required this.time,
    required this.canEdit,
    required this.canCancel,
    required this.onEdit,
    required this.onCancel,
  });

  final Appointment appointment;
  final String date;
  final String time;
  final bool canEdit;
  final bool canCancel;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  /// Builds the centered appointment details dialog.
  @override
  Widget build(BuildContext context) {
    final changeRequest = appointment.changeRequest;
    final usedRequests = appointment.editRequestCount;
    final remainingRequests = appointment.remainingEditRequests;
    final maximumRequests = AppointmentService.maximumEditRequests;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog heading and close button.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Appointment Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Doctor information and appointment status.
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.doctorName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                        ),
                        Text(
                          appointment.specialty,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppointmentStatusChip(status: appointment.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),

              Text(
                appointment.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              _DialogDetailRow(
                icon: Icons.calendar_month_rounded,
                label: 'Date',
                value: date,
              ),
              _DialogDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: time,
              ),
              _DialogDetailRow(
                icon: appointment.isVideo
                    ? Icons.videocam_rounded
                    : Icons.local_hospital_outlined,
                label: 'Consultation Type',
                value: appointment.isVideo
                    ? 'Video Consultation'
                    : 'In-person Consultation',
              ),
              _DialogDetailRow(
                icon: Icons.location_on_outlined,
                label: appointment.isVideo ? 'Platform' : 'Location',
                value: appointment.location,
              ),
              _DialogDetailRow(
                icon: Icons.payments_outlined,
                label: 'Consultation Fee',
                value: appointment.consultationFee != null
                    ? '₱${appointment.consultationFee!.toStringAsFixed(2)}'
                    : 'Not specified',
              ),
              _DialogDetailRow(
                icon: Icons.notifications_outlined,
                label: 'Appointment Reminder',
                value: appointment.reminderEnabled ? 'Enabled' : 'Disabled',
              ),

              // Displays the patient's edit-request allowance.
              const SizedBox(height: AppSpacing.sm),
              _buildPolicyCard(
                context,
                usedRequests: usedRequests,
                remainingRequests: remainingRequests,
                maximumRequests: maximumRequests,
              ),

              // Displays change-request status and proposed details.
              if (changeRequest != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Change Request',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChangeRequestStatusText(status: changeRequest.status),
                const SizedBox(height: AppSpacing.sm),
                _DialogDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Requested Doctor',
                  value: changeRequest.doctorName,
                ),
                _DialogDetailRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Requested Date',
                  value: MaterialLocalizations.of(context)
                      .formatMediumDate(changeRequest.dateTime),
                ),
                _DialogDetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Requested Time',
                  value: MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(changeRequest.dateTime),
                  ),
                ),
                _DialogDetailRow(
                  icon: Icons.medical_services_outlined,
                  label: 'Requested Consultation',
                  value: changeRequest.isVideo
                      ? 'Video Consultation'
                      : 'In-person Consultation',
                ),
                _DialogDetailRow(
                  icon: Icons.location_on_outlined,
                  label: changeRequest.isVideo
                      ? 'Requested Platform'
                      : 'Requested Location',
                  value: changeRequest.location,
                ),
                _DialogDetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Requested Fee',
                  value: changeRequest.consultationFee != null
                      ? '₱${changeRequest.consultationFee!.toStringAsFixed(2)}'
                      : 'Not specified',
                ),
                _DialogDetailRow(
                  icon: Icons.notifications_outlined,
                  label: 'Requested Reminder',
                  value: changeRequest.reminderEnabled ? 'Enabled' : 'Disabled',
                ),
                if (changeRequest.status == ChangeRequestStatus.pending)
                  Text(
                    'Your current appointment details will remain unchanged '
                    'until the doctor approves this request.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                if (changeRequest.status == ChangeRequestStatus.rejected)
                  Text(
                    'Your original appointment details remain unchanged.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Patient management actions appear only inside this dialog.
              if (canEdit) ...[
                SizedBox(
                  width: double.infinity,
                  child: H360Button(
                    label: 'Edit Appointment',
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              if (canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Appointment'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Explains why editing is unavailable.
              if (!canEdit && canCancel) ...[
                Text(
                  appointment.changeRequest?.status ==
                          ChangeRequestStatus.pending
                      ? 'You cannot submit another edit while a change request '
                          'is awaiting doctor approval.'
                      : remainingRequests == 0
                          ? 'You have reached the maximum of two edit requests '
                              'for this appointment.'
                          : 'The editing period for this appointment has expired.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the editing policy and remaining-request information.
  Widget _buildPolicyCard(
    BuildContext context, {
    required int usedRequests,
    required int remainingRequests,
    required int maximumRequests,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Appointment Editing Policy',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You may request changes within 24 hours after booking. '
            'You are allowed a maximum of $maximumRequests edit requests '
            'for this appointment.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
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
              color:
                  remainingRequests > 0 ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays one labeled detail row inside the appointment dialog.
class _DialogDetailRow extends StatelessWidget {
  /// Creates a detail row.
  const _DialogDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Builds the detail row.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
