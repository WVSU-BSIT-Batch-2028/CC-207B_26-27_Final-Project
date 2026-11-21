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

enum _LoadStatus { loading, ready, error }

enum _AppointmentFilter { all, pending, confirmed, cancelled }

/// Doctor Appointment Management screen.
///
/// Displays all appointments available in the shared AppointmentService.
/// Doctors can search patients, filter by appointment status, view details,
/// confirm or cancel appointments, and add Google Meet links.
class DoctorAppointmentsScreen extends StatefulWidget {
  /// Creates the doctor appointments screen.
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

/// Manages appointment loading, searching, filtering, and doctor actions.
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

  /// Updates the search query when the doctor types a patient name.
  void _searchAppointments(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  /// Changes the selected appointment status filter.
  void _changeFilter(_AppointmentFilter filter) {
    setState(() => _filter = filter);
  }

  /// Counts appointments belonging to the selected status.
  int _countAppointments(_AppointmentFilter filter) {
    if (filter == _AppointmentFilter.all) {
      return _appointments.length;
    }

    return _appointments.where((appointment) {
      return appointment.status.name == filter.name;
    }).length;
  }

  /// Returns appointments matching the search query and selected filter.
  List<Appointment> _filteredAppointments() {
    final filtered = _appointments.where((appointment) {
      final patientName = (appointment.patientName ?? '').toLowerCase();

      final matchesSearch = patientName.contains(_searchQuery);

      final matchesFilter = _filter == _AppointmentFilter.all ||
          appointment.status.name == _filter.name;

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return filtered;
  }

  /// Formats an appointment date using the device's locale.
  String _formatDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  /// Formats an appointment time using the device's locale.
  String _formatTime(DateTime date) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
  }

  /// Runs a doctor action and refreshes the shared appointment list.
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

  /// Confirms a pending appointment through AppointmentService.
  Future<void> _confirmAppointment(Appointment appointment) async {
    await _runManagementAction(
      action: () => AppointmentService.instance.confirmAppointment(
        appointment.id,
      ),
      successMessage: 'Appointment confirmed successfully.',
    );
  }

  /// Asks the doctor to confirm before cancelling an appointment.
  Future<void> _cancelAppointment(Appointment appointment) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          'Are you sure you want to cancel the appointment for '
          '${appointment.patientName ?? 'this patient'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Appointment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Appointment'),
          ),
        ],
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

  /// Opens the separate Google Meet dialog and saves the returned URL.
  Future<void> _openMeetingUrlDialog(Appointment appointment) async {
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

  /// Opens the centered appointment details dialog.
  void _showAppointmentDetails(Appointment appointment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog heading.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Appointment Details',
                            style: Theme.of(dialogContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Patient information.
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
                      value: _formatDate(appointment.dateTime),
                      icon: Icons.calendar_month_outlined,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Time',
                      value: _formatTime(appointment.dateTime),
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
                      value:
                          appointment.reminderEnabled ? 'Enabled' : 'Disabled',
                      icon: Icons.notifications_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Current appointment status.
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

                    // Existing meeting link.
                    if (appointment.isVideo &&
                        appointment.meetingUrl != null) ...[
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

                    const SizedBox(height: AppSpacing.lg),

                    // Pending appointments can be confirmed.
                    if (appointment.status == AppointmentStatus.pending) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isActionInProgress
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                  _confirmAppointment(appointment);
                                },
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                          ),
                          label: const Text('Confirm Appointment'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Confirmed video appointments can receive a meeting link.
                    if (appointment.status == AppointmentStatus.confirmed &&
                        appointment.isVideo) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isActionInProgress
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                  _openMeetingUrlDialog(appointment);
                                },
                          icon: const Icon(Icons.video_call_rounded),
                          label: Text(
                            appointment.meetingUrl == null
                                ? 'Add Google Meet Link'
                                : 'Update Google Meet Link',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Appointments that are not cancelled can be cancelled.
                    if (appointment.status != AppointmentStatus.cancelled)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isActionInProgress
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                  _cancelAppointment(appointment);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(
                              color: AppColors.danger,
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel Appointment'),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
            // Page heading.
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

            // Appointment status summary.
            const SectionHeader(
              title: 'Appointment Overview',
              subtitle: 'Summary of all available appointments.',
            ),
            _buildSummary(),

            // Patient search.
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

            // Status filters.
            _buildFilters(),
            const SizedBox(height: AppSpacing.md),

            // Appointment list state.
            _buildAppointmentContent(),
          ],
        ),
      ),
    );
  }

  /// Builds the four compact appointment summary tiles.
  Widget _buildSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A higher aspect ratio makes each summary tile shorter.
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
    switch (filter) {
      case _AppointmentFilter.all:
        return 'All (${_countAppointments(filter)})';
      case _AppointmentFilter.pending:
        return 'Pending (${_countAppointments(filter)})';
      case _AppointmentFilter.confirmed:
        return 'Confirmed (${_countAppointments(filter)})';
      case _AppointmentFilter.cancelled:
        return 'Cancelled (${_countAppointments(filter)})';
    }
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
                ),
              ),
          ],
        );
    }
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

    _controller = TextEditingController(
      text: widget.initialUrl ?? '',
    );
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
    return AlertDialog(
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
              Navigator.pop(
                context,
                _controller.text.trim(),
              );
            }
          },
          child: const Text('Save Link'),
        ),
      ],
    );
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
  });

  final Appointment appointment;
  final String date;
  final String time;
  final VoidCallback onTap;

  /// Builds the appointment summary card.
  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient name and appointment status.
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

          // Specialty and appointment title.
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

          // Schedule and consultation type.
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
                  appointment.consultationFee == null
                      ? 'Fee not specified'
                      : 'Fee: ₱${appointment.consultationFee!.toStringAsFixed(2)}',
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
