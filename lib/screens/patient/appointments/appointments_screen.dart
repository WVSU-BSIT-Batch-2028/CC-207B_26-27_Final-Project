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

enum _LoadStatus { loading, ready, error }

enum _AppointmentFilter { upcoming, past }

/// Patient Appointments Overview.
///
/// Displays upcoming and past appointments, including doctor information,
/// consultation type, schedule, and appointment status.
///
/// Data is retrieved through AppointmentService. The screen also supports
/// loading, empty, error, and pull-to-refresh states.
class AppointmentsScreen extends StatefulWidget {
  /// Creates the patient appointments screen.
  const AppointmentsScreen({
    super.key,
    required this.onBookAppointment,
    required this.onJoinConsultation,
  });

  /// Called when the patient taps the Book Appointment button.
  final VoidCallback onBookAppointment;

  /// Called when the patient opens a video consultation screen.
  final ValueChanged<Appointment> onJoinConsultation;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

/// Manages appointment loading, filtering, and display.
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
  ///
  /// When showLoading is false, the existing content remains visible
  /// while refreshing.
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

  /// Returns appointments based on the selected Upcoming or Past filter.
  List<Appointment> _filteredAppointments() {
    final now = DateTime.now();

    final filtered = _appointments.where((appointment) {
      if (_filter == _AppointmentFilter.upcoming) {
        return !appointment.dateTime.isBefore(now);
      }

      return appointment.dateTime.isBefore(now);
    }).toList();

    // Upcoming appointments appear earliest first.
    // Past appointments appear newest first.
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
            // Screen heading.
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

            // Booking action.
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

            // Upcoming and Past filters.
            _buildFilters(),

            const SizedBox(height: AppSpacing.md),

            // Loading, error, or appointment list.
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

/// Displays one appointment's information and available actions.
class _AppointmentCard extends StatelessWidget {
  /// Creates an appointment card.
  const _AppointmentCard({
    required this.appointment,
    required this.date,
    required this.time,
    required this.onJoinConsultation,
  });

  final Appointment appointment;
  final String date;
  final String time;
  final VoidCallback? onJoinConsultation;

  /// Builds the appointment card.
  @override
  Widget build(BuildContext context) {
    return H360Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor information and appointment status.
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
                      appointment.doctorName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                    const SizedBox(height: 3),
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
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Appointment title.
          Text(
            appointment.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Date and time.
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

          // Consultation type and location.
          _AppointmentInfoRow(
            icon: appointment.isVideo
                ? Icons.videocam_rounded
                : Icons.location_on_outlined,
            text: appointment.isVideo
                ? 'Video Consultation'
                : appointment.location,
          ),

          // Video consultation navigation.
          if (appointment.isVideo) ...[
            const SizedBox(height: AppSpacing.md),
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
        Icon(
          icon,
          size: 17,
          color: AppColors.textMuted,
        ),
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
