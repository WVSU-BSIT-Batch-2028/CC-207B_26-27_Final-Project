import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/appointment.dart';
import '../../../models/appointment_status.dart';
import '../../../services/appointment_service.dart';
import '../../../widgets/appointment_status_chip.dart';
import '../../../widgets/h360_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/dialog_frame.dart';

enum _LoadStatus { loading, ready, error }

enum _AppointmentFilter {
  all,
  pending,
  confirmed,
  cancelled,
  done,
  noShow,
}

/// Doctor Appointment Management screen.
///
/// Displays appointments from the shared AppointmentService. Doctors can
/// search and filter appointments, review change requests through the
/// appointment details modal, manage consultations, and record outcomes.
class DoctorAppointmentsScreen extends StatefulWidget {
  /// Creates the doctor appointments screen.
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

/// Manages appointment loading, filtering, and doctor actions.
class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  _LoadStatus _loadStatus = _LoadStatus.loading;
  _AppointmentFilter _filter = _AppointmentFilter.all;

  List<Appointment> _appointments = [];

  String _searchQuery = '';
  String _error = '';
  bool _isActionInProgress = false;

  /// Loads appointments when the screen is initialized.
  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  /// Retrieves appointments from the shared appointment service.
  Future<void> _loadAppointments({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _loadStatus = _LoadStatus.loading);
    }

    try {
      final appointments =
          await AppointmentService.instance.fetchAppointments();

      if (!mounted) return;

      setState(() {
        _appointments = appointments;
        _loadStatus = _LoadStatus.ready;
        _error = '';
      });
    } on AppointmentException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loadStatus = _LoadStatus.error;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load appointments. Please try again.';
        _loadStatus = _LoadStatus.error;
      });
    }
  }

  /// Updates the patient search query.
  void _searchAppointments(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  /// Changes the selected appointment filter.
  void _changeFilter(_AppointmentFilter filter) {
    setState(() => _filter = filter);
  }

  /// Counts appointments belonging to the selected filter.
  int _countAppointments(_AppointmentFilter filter) {
    if (filter == _AppointmentFilter.all) {
      return _appointments.length;
    }

    return _appointments.where((appointment) {
      if (filter == _AppointmentFilter.done) {
        return appointment.outcome == AppointmentOutcome.done;
      }

      if (filter == _AppointmentFilter.noShow) {
        return appointment.outcome == AppointmentOutcome.noShow;
      }

      return appointment.status.name == filter.name;
    }).length;
  }

  /// Returns appointments matching the search query and selected filter.
  List<Appointment> _filteredAppointments() {
    final filtered = _appointments.where((appointment) {
      final patientName = (appointment.patientName ?? '').toLowerCase();
      final matchesSearch = patientName.contains(_searchQuery);

      final matchesFilter = switch (_filter) {
        _AppointmentFilter.all => true,
        _AppointmentFilter.done =>
          appointment.outcome == AppointmentOutcome.done,
        _AppointmentFilter.noShow =>
          appointment.outcome == AppointmentOutcome.noShow,
        _ => appointment.status.name == _filter.name,
      };

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return filtered;
  }

  /// Formats an appointment date using the device locale.
  String _formatDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  /// Formats an appointment time using the device locale.
  String _formatTime(DateTime date) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
  }

  /// Checks whether an appointment is scheduled for the future.
  bool _isUpcoming(Appointment appointment) {
    return appointment.dateTime.isAfter(DateTime.now()) &&
        appointment.status != AppointmentStatus.cancelled &&
        appointment.outcome == AppointmentOutcome.none;
  }

  /// Checks whether a past appointment still needs an outcome.
  bool _canRecordOutcome(Appointment appointment) {
    return appointment.dateTime.isBefore(DateTime.now()) &&
        appointment.status != AppointmentStatus.cancelled &&
        appointment.outcome == AppointmentOutcome.none;
  }

  /// Checks whether a doctor can manage the meeting link.
  bool _canManageMeetingLink(Appointment appointment) {
    return _isUpcoming(appointment) &&
        appointment.status == AppointmentStatus.confirmed &&
        appointment.isVideo &&
        appointment.changeRequest?.status != ChangeRequestStatus.pending;
  }

  /// Runs a doctor action and refreshes the appointment list.
  Future<void> _runManagementAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_isActionInProgress) return;

    setState(() => _isActionInProgress = true);

    try {
      await action();

      final updatedAppointments =
          await AppointmentService.instance.fetchAppointments();

      if (!mounted) return;

      setState(() {
        _appointments = updatedAppointments;
        _loadStatus = _LoadStatus.ready;
        _error = '';
        _isActionInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on AppointmentException catch (e) {
      if (!mounted) return;

      setState(() => _isActionInProgress = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isActionInProgress = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The action could not be completed. Please try again.',
          ),
        ),
      );
    }
  }

  /// Opens a separate confirmation dialog before confirming an appointment.
  Future<void> _confirmAppointment(Appointment appointment) async {
    if (!_isUpcoming(appointment) ||
        appointment.status != AppointmentStatus.pending) {
      return;
    }

    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ActionConfirmationDialog(
        title: 'Confirm Appointment?',
        description:
            "Confirm this patient's appointment. The appointment status "
            'will be changed to Confirmed.',
        confirmLabel: 'Confirm Appointment',
        icon: Icons.check_circle_outline_rounded,
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );

    if (shouldConfirm != true || !mounted) return;

    await _runManagementAction(
      action: () => AppointmentService.instance.confirmAppointment(
        appointment.id,
      ),
      successMessage: 'Appointment confirmed successfully.',
    );
  }

  /// Cancels an upcoming appointment after doctor confirmation.
  Future<void> _cancelAppointment(Appointment appointment) async {
    if (!_isUpcoming(appointment)) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ActionConfirmationDialog(
        title: 'Cancel Appointment?',
        description: 'Are you sure you want to cancel the appointment for '
            '${appointment.patientName ?? 'this patient'}?',
        confirmLabel: 'Cancel Appointment',
        isDestructive: true,
        icon: Icons.cancel_outlined,
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );

    if (shouldCancel != true || !mounted) return;

    await _runManagementAction(
      action: () => AppointmentService.instance.cancelAppointment(
        appointment.id,
      ),
      successMessage: 'Appointment cancelled successfully.',
    );
  }

  /// Opens the change request review dialog.
  Future<void> _openChangeRequestReview(Appointment appointment) async {
    final request = appointment.changeRequest;

    if (request == null || request.status != ChangeRequestStatus.pending) {
      return;
    }

    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ChangeRequestReviewDialog(
        appointment: appointment,
        formatDate: _formatDate,
        formatTime: _formatTime,
      ),
    );

    if (decision == null || !mounted) return;

    await _runManagementAction(
      action: () async {
        if (decision) {
          await AppointmentService.instance.approveAppointmentChange(
            appointment.id,
          );
        } else {
          await AppointmentService.instance.rejectAppointmentChange(
            appointment.id,
          );
        }
      },
      successMessage: decision
          ? 'Appointment change request approved.'
          : 'Appointment change request rejected.',
    );
  }

  /// Records the outcome of a past appointment.
  Future<void> _recordAppointmentOutcome(
    Appointment appointment, {
    required bool markDone,
  }) async {
    if (!_canRecordOutcome(appointment)) return;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ActionConfirmationDialog(
        title: markDone ? 'Mark Appointment as Done?' : 'Mark as No-show?',
        description: markDone
            ? '${appointment.patientName ?? 'The patient'} completed '
                'this appointment.'
            : '${appointment.patientName ?? 'The patient'} did not attend '
                'this appointment.',
        confirmLabel: markDone ? 'Mark as Done' : 'Mark as No-show',
        isDestructive: !markDone,
        icon: markDone
            ? Icons.check_circle_outline_rounded
            : Icons.person_off_outlined,
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );

    if (shouldProceed != true || !mounted) return;

    await _runManagementAction(
      action: () async {
        if (markDone) {
          await AppointmentService.instance.markAppointmentDone(
            appointment.id,
          );
        } else {
          await AppointmentService.instance.markAppointmentNoShow(
            appointment.id,
          );
        }
      },
      successMessage: markDone
          ? 'Appointment marked as Done.'
          : 'Appointment marked as No-show.',
    );
  }

  /// Opens the Google Meet URL dialog and saves the returned link.
  Future<void> _openMeetingUrlDialog(Appointment appointment) async {
    if (!_canManageMeetingLink(appointment)) return;

    final meetingUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _MeetingUrlDialog(
        initialUrl: appointment.meetingUrl,
      ),
    );

    if (meetingUrl == null || !mounted) return;

    await _runManagementAction(
      action: () => AppointmentService.instance.updateMeetingUrl(
        appointmentId: appointment.id,
        meetingUrl: meetingUrl,
      ),
      successMessage: 'Google Meet link saved successfully.',
    );
  }

  /// Opens the appointment details modal.
  ///
  /// A pending change request can be reviewed directly from this modal.
  void _showAppointmentDetails(Appointment appointment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AppointmentDetailsDialog(
        appointment: appointment,
        date: _formatDate(appointment.dateTime),
        time: _formatTime(appointment.dateTime),
        onReviewRequest:
            appointment.changeRequest?.status == ChangeRequestStatus.pending
                ? () {
                    Navigator.pop(dialogContext);
                    _openChangeRequestReview(appointment);
                  }
                : null,
      ),
    );
  }

  /// Builds the main doctor appointments page.
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
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Review patient schedules and manage consultations.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SectionHeader(
              title: 'Appointment Overview',
              subtitle: 'Summary of all available appointments.',
            ),
            _buildSummary(),
            const SectionHeader(title: 'Patient Appointments'),
            TextField(
              onChanged: _searchAppointments,
              decoration: AppTheme.inputDecoration(
                hint: 'Search by patient name',
              ).copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildFilters(),
            const SizedBox(height: AppSpacing.md),
            _buildAppointmentContent(),
          ],
        ),
      ),
    );
  }

  /// Builds the appointment summary tiles.
  Widget _buildSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = constraints.maxWidth >= 900
            ? 5.8
            : constraints.maxWidth >= 600
                ? 4.0
                : 2.5;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: aspectRatio,
          children: [
            _SummaryTile(
              label: 'All',
              count: _countAppointments(_AppointmentFilter.all),
              icon: Icons.event_note_rounded,
              color: AppColors.primary,
            ),
            _SummaryTile(
              label: 'Pending',
              count: _countAppointments(_AppointmentFilter.pending),
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
            ),
            _SummaryTile(
              label: 'Confirmed',
              count: _countAppointments(_AppointmentFilter.confirmed),
              icon: Icons.event_available_rounded,
              color: AppColors.success,
            ),
            _SummaryTile(
              label: 'Cancelled',
              count: _countAppointments(_AppointmentFilter.cancelled),
              icon: Icons.event_busy_rounded,
              color: AppColors.danger,
            ),
          ],
        );
      },
    );
  }

  /// Builds the appointment status filter controls.
  Widget _buildFilters() {
    const filters = [
      _AppointmentFilter.all,
      _AppointmentFilter.pending,
      _AppointmentFilter.confirmed,
      _AppointmentFilter.cancelled,
      _AppointmentFilter.done,
      _AppointmentFilter.noShow,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(_filterLabel(filter)),
                selected: _filter == filter,
                onSelected: (_) => _changeFilter(filter),
                selectedColor: AppColors.brandNavy,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: _filter == filter ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: _filter == filter
                      ? AppColors.brandNavy
                      : AppColors.border,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns the display label for an appointment filter.
  String _filterLabel(_AppointmentFilter filter) {
    final label = switch (filter) {
      _AppointmentFilter.all => 'All',
      _AppointmentFilter.pending => 'Pending',
      _AppointmentFilter.confirmed => 'Confirmed',
      _AppointmentFilter.cancelled => 'Cancelled',
      _AppointmentFilter.done => 'Done',
      _AppointmentFilter.noShow => 'No-show',
    };

    return '$label (${_countAppointments(filter)})';
  }

  /// Displays loading, error, empty, or appointment-list content.
  Widget _buildAppointmentContent() {
    switch (_loadStatus) {
      case _LoadStatus.loading:
        return const Column(
          children: [
            SkeletonBox(height: 145, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 145, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 145, radius: AppRadius.md),
          ],
        );

      case _LoadStatus.error:
        return ErrorState(
          message: _error,
          onRetry: _loadAppointments,
        );

      case _LoadStatus.ready:
        final appointments = _filteredAppointments();

        if (appointments.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_rounded,
            title: _searchQuery.isNotEmpty
                ? 'No matching appointments'
                : 'No appointments found',
            message: _searchQuery.isNotEmpty
                ? 'Try another patient name or change the selected status filter.'
                : 'Appointments will appear here when they are available.',
          );
        }

        return Column(
          children: [
            for (final appointment in appointments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _DoctorAppointmentCard(
                  appointment: appointment,
                  date: _formatDate(appointment.dateTime),
                  time: _formatTime(appointment.dateTime),
                  onTap: () => _showAppointmentDetails(appointment),
                  onConfirm: appointment.status == AppointmentStatus.pending &&
                          _isUpcoming(appointment)
                      ? () => _confirmAppointment(appointment)
                      : null,
                  onMeetingUrl: _canManageMeetingLink(appointment)
                      ? () => _openMeetingUrlDialog(appointment)
                      : null,
                  hasMeetingUrl: appointment.meetingUrl != null &&
                      appointment.meetingUrl!.isNotEmpty,
                  onCancel: _isUpcoming(appointment)
                      ? () => _cancelAppointment(appointment)
                      : null,
                  onMarkDone: _canRecordOutcome(appointment)
                      ? () => _recordAppointmentOutcome(
                            appointment,
                            markDone: true,
                          )
                      : null,
                  onMarkNoShow: _canRecordOutcome(appointment)
                      ? () => _recordAppointmentOutcome(
                            appointment,
                            markDone: false,
                          )
                      : null,
                ),
              ),
          ],
        );
    }
  }
}

/// Displays appointment details and provides access to pending change requests.
class _AppointmentDetailsDialog extends StatelessWidget {
  /// Creates the appointment details dialog.
  const _AppointmentDetailsDialog({
    required this.appointment,
    required this.date,
    required this.time,
    this.onReviewRequest,
  });

  final Appointment appointment;
  final String date;
  final String time;
  final VoidCallback? onReviewRequest;

  /// Builds the appointment details dialog.
  @override
  Widget build(BuildContext context) {
    // Colour, corners and outline come from the dialog theme (AppTheme).
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSizes.detailDialog,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Appointment Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
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
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Patient',
                  value: appointment.patientName ?? 'Not provided',
                  icon: Icons.person_outline_rounded,
                ),
                if (appointment.patientId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    label: 'Patient ID',
                    value: appointment.patientId!,
                    icon: Icons.badge_outlined,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Doctor',
                  value: appointment.doctorName,
                  icon: Icons.medical_services_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Specialty',
                  value: appointment.specialty,
                  icon: Icons.local_hospital_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Date',
                  value: date,
                  icon: Icons.calendar_month_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Time',
                  value: time,
                  icon: Icons.access_time_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Consultation Type',
                  value: appointment.isVideo
                      ? 'Video Consultation'
                      : 'In-person Consultation',
                  icon: appointment.isVideo
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Location',
                  value: appointment.location,
                  icon: Icons.place_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Consultation Fee',
                  value: appointment.consultationFee == null
                      ? 'Not specified'
                      : '₱${appointment.consultationFee!.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Reminder',
                  value: appointment.reminderEnabled ? 'Enabled' : 'Disabled',
                  icon: Icons.notifications_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppointmentStatusChip(status: appointment.status),
                  ],
                ),
                if (appointment.outcome != AppointmentOutcome.none) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    label: 'Appointment Outcome',
                    value: switch (appointment.outcome) {
                      AppointmentOutcome.done => 'Done',
                      AppointmentOutcome.noShow => 'No-show',
                      AppointmentOutcome.none => 'Not marked',
                    },
                    icon: appointment.outcome == AppointmentOutcome.done
                        ? Icons.check_circle_outline_rounded
                        : Icons.person_off_outlined,
                  ),
                ],
                if (appointment.isVideo && appointment.meetingUrl != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Google Meet Link',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    appointment.meetingUrl!,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (appointment.changeRequest != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.sm),
                  _ChangeRequestStatusSummary(
                    request: appointment.changeRequest!,
                  ),
                  if (onReviewRequest != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onReviewRequest,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Review Change Request'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays a brief summary of the latest change request.
class _ChangeRequestStatusSummary extends StatelessWidget {
  /// Creates the change request summary.
  const _ChangeRequestStatusSummary({required this.request});

  final AppointmentChangeRequest request;

  /// Builds the change request summary.
  @override
  Widget build(BuildContext context) {
    final statusText = switch (request.status) {
      ChangeRequestStatus.pending => 'Pending Review',
      ChangeRequestStatus.approved => 'Approved',
      ChangeRequestStatus.rejected => 'Rejected',
    };

    final statusColor = switch (request.status) {
      ChangeRequestStatus.pending => AppColors.warning,
      ChangeRequestStatus.approved => AppColors.success,
      ChangeRequestStatus.rejected => AppColors.danger,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Latest Change Request',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.status == ChangeRequestStatus.pending
                ? 'The patient has submitted changes awaiting your review.'
                : 'This request has already been reviewed.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated dialog for reviewing a patient's requested appointment changes.
class _ChangeRequestReviewDialog extends StatelessWidget {
  /// Creates the change request review dialog.
  const _ChangeRequestReviewDialog({
    required this.appointment,
    required this.formatDate,
    required this.formatTime,
  });

  final Appointment appointment;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  /// Builds the change request review dialog.
  @override
  Widget build(BuildContext context) {
    final request = appointment.changeRequest!;

    // Colour, corners and outline come from the dialog theme (AppTheme).
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSizes.detailDialog,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Review Change Request',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
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
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Review the proposed appointment details before making '
                  'a decision.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Current Appointment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Doctor',
                  value: appointment.doctorName,
                  icon: Icons.medical_services_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Date and Time',
                  value: '${formatDate(appointment.dateTime)} '
                      '${formatTime(appointment.dateTime)}',
                  icon: Icons.calendar_month_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Consultation Type',
                  value: appointment.isVideo
                      ? 'Video Consultation'
                      : 'In-person Consultation',
                  icon: Icons.video_call_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Requested Changes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Requested Doctor',
                  value: request.doctorName,
                  icon: Icons.medical_services_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Requested Specialty',
                  value: request.specialty,
                  icon: Icons.local_hospital_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Requested Date',
                  value: formatDate(request.dateTime),
                  icon: Icons.calendar_month_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Requested Time',
                  value: formatTime(request.dateTime),
                  icon: Icons.access_time_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Consultation Type',
                  value: request.isVideo
                      ? 'Video Consultation'
                      : 'In-person Consultation',
                  icon: request.isVideo
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Requested Location',
                  value: request.location,
                  icon: Icons.place_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Requested Fee',
                  value: request.consultationFee == null
                      ? 'Not specified'
                      : '₱${request.consultationFee!.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Reminder',
                  value: request.reminderEnabled ? 'Enabled' : 'Disabled',
                  icon: Icons.notifications_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Requested On',
                  value: '${formatDate(request.requestedAt)} '
                      '${formatTime(request.requestedAt)}',
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Approving this request will replace the current '
                    'appointment details. Rejecting it will keep the original '
                    'appointment unchanged.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Approve Request'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject Request'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable confirmation dialog for doctor appointment actions.
class _ActionConfirmationDialog extends StatelessWidget {
  /// Creates an action confirmation dialog.
  const _ActionConfirmationDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.icon,
    required this.onCancel,
    required this.onConfirm,
    this.isDestructive = false,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final IconData icon;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  /// Builds the action confirmation dialog.
  @override
  Widget build(BuildContext context) {
    return DialogFrame(child: AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Go Back'),
        ),
        FilledButton.icon(
          onPressed: onConfirm,
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          icon: Icon(icon, size: 18),
          label: Text(confirmLabel),
        ),
      ],
    ));
  }
}

/// Dialog for adding or updating a Google Meet URL.
class _MeetingUrlDialog extends StatefulWidget {
  /// Creates the Google Meet URL dialog.
  const _MeetingUrlDialog({this.initialUrl});

  final String? initialUrl;

  @override
  State<_MeetingUrlDialog> createState() => _MeetingUrlDialogState();
}

/// Manages the Google Meet form and its controller lifecycle.
class _MeetingUrlDialogState extends State<_MeetingUrlDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _controller;

  /// Initializes the controller with the existing URL, if available.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '');
  }

  /// Releases the controller when the dialog is removed.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Validates the Google Meet URL format.
  String? _validateMeetingUrl(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Please enter the Google Meet link.';
    }

    final uri = Uri.tryParse(text);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'meet.google.com' ||
        uri.pathSegments.isEmpty) {
      return 'Enter a valid Google Meet URL.';
    }

    return null;
  }

  /// Builds the Google Meet URL form.
  @override
  Widget build(BuildContext context) {
    return DialogFrame(child: AlertDialog(
      title: Text(
        widget.initialUrl == null
            ? 'Add Google Meet Link'
            : 'Update Google Meet Link',
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.url,
          decoration: AppTheme.inputDecoration(
            label: 'Google Meet URL',
            hint: 'https://meet.google.com/abc-defg-hij',
          ),
          validator: _validateMeetingUrl,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Save Link'),
        ),
      ],
    ));
  }
}

/// Displays one appointment summary in the doctor's appointment list.
class _DoctorAppointmentCard extends StatelessWidget {
  /// Creates an appointment card for the doctor.
  const _DoctorAppointmentCard({
    required this.appointment,
    required this.date,
    required this.time,
    required this.onTap,
    this.onConfirm,
    this.onMeetingUrl,
    this.hasMeetingUrl = false,
    this.onCancel,
    this.onMarkDone,
    this.onMarkNoShow,
  });

  final Appointment appointment;
  final String date;
  final String time;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onMeetingUrl;
  final bool hasMeetingUrl;
  final VoidCallback? onCancel;
  final VoidCallback? onMarkDone;
  final VoidCallback? onMarkNoShow;

  /// Builds the appointment summary card.
  @override
  Widget build(BuildContext context) {
    final consultationFee = appointment.consultationFee;

    return H360Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientName ?? 'Patient name unavailable',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
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
          Text(
            appointment.title,
            style: const TextStyle(
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
            icon: appointment.isVideo
                ? Icons.videocam_rounded
                : Icons.location_on_outlined,
            text: appointment.isVideo
                ? 'Video Consultation'
                : appointment.location,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  consultationFee == null
                      ? 'Fee not specified'
                      : 'Fee: ₱${consultationFee.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'View Details',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AppColors.primary,
              ),
            ],
          ),
          if (onConfirm != null ||
              onMeetingUrl != null ||
              onCancel != null ||
              onMarkDone != null ||
              onMarkNoShow != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: AppSpacing.md),
            if (onConfirm != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirm Appointment'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (onMeetingUrl != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onMeetingUrl,
                  icon: const Icon(Icons.video_call_outlined),
                  label: Text(
                    hasMeetingUrl ? 'Update Meet Link' : 'Add Meet Link',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (onCancel != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Appointment'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (onMarkDone != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark as Done'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (onMarkNoShow != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onMarkNoShow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Mark as No-show'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Displays one appointment summary in the overview grid.
class _SummaryTile extends StatelessWidget {
  /// Creates an appointment summary tile.
  const _SummaryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  /// Builds the summary tile.
  @override
  Widget build(BuildContext context) {
    return H360Card(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
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

/// Displays one appointment detail with a leading icon.
class _DetailRow extends StatelessWidget {
  /// Creates an appointment detail row.
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Builds the detail row.
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.textMuted),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
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
    );
  }
}

/// Displays an icon and a short appointment detail in a list card.
class _AppointmentInfoRow extends StatelessWidget {
  /// Creates an appointment information row.
  const _AppointmentInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  /// Builds the appointment information row.
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
