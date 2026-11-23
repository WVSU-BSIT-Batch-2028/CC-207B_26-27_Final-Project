import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_format.dart';
import '../../models/doctor_dashboard_data.dart';
import '../../models/user_role.dart';
import '../../services/dashboard_service.dart';
import '../../services/doctor_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/coming_soon_sheet.dart';
import '../../widgets/demo_scenario_sheet.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/h360_button.dart';
import '../../widgets/h360_card.dart';
import '../../widgets/hero_panel.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import 'widgets/appointment_row.dart';
import 'widgets/overview_tile.dart';

enum _LoadStatus { loading, ready, error }

/// Doctor landing page: today's schedule + quick overview.
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key, required this.onNavigate, required this.onOpenDashboard});

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenDashboard;

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  DoctorDashboardData? _data;
  String? _doctorDisplayName;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final results = await Future.wait([
        DoctorService.instance.fetchDashboard(),
        ProfileService.instance.load(UserRole.doctor),
      ]);
      if (!mounted) return;
      final data = results[0] as DoctorDashboardData;
      final profile = results[1] as dynamic;
      final clean = (profile.fullName as String)
          .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
          .trim();
      final shortName = clean.isEmpty
          ? data.doctorShortName
          : 'Dr. ${clean.split(RegExp(r'\s+')).last}';

      setState(() {
        _data = data;
        _doctorDisplayName = shortName;
        _status = _LoadStatus.ready;
      });
    } on DashboardException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _load(showSkeleton: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: _buildChildren(),
        ),
      ),
    );
  }

  Widget _header(String? name) {
    final greeting = greetingFor(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting,', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              Text(
                name == null ? 'Doctor' : '$name!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: 2),
              Text('Your care makes a difference.', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Open profile',
          child: GestureDetector(
            onTap: () => widget.onNavigate(3),
            onLongPress: () => showDemoScenarioSheet(context, _load),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(Icons.person_outline_rounded, color: AppColors.navy),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.lg);

    switch (_status) {
      case _LoadStatus.loading:
        return [_header(null), gap, const DashboardSkeleton()];

      case _LoadStatus.error:
        return [_header(null), ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        final d = _data!;
        final hasAppointments = d.todayAppointments > 0;
        final displayName = _doctorDisplayName ?? d.doctorShortName;

        return [
          FadeSlideIn(child: _header(displayName)),
          gap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: HeroPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Today's Schedule",
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    hasAppointments ? '${d.todayAppointments} Appointments' : 'No appointments today',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (d.nextUp != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Next up: ${d.nextUp}',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  H360Button(
                    label: 'View Schedule',
                    icon: Icons.arrow_forward_rounded,
                    inverted: true,
                    onPressed: () => widget.onNavigate(1),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: 'Quick Overview', actionLabel: 'Full dashboard', onAction: widget.onOpenDashboard),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OverviewTile(
                        icon: Icons.event_available_rounded,
                        value: '${d.todayAppointments}',
                        label: 'Appointments',
                        color: AppColors.primary,
                        onTap: () => widget.onNavigate(1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OverviewTile(
                        icon: Icons.groups_rounded,
                        value: '${d.patients}',
                        label: 'Patients',
                        color: AppColors.weight,
                        onTap: () => widget.onNavigate(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OverviewTile(
                        icon: Icons.medication_rounded,
                        value: '${d.prescriptions}',
                        label: 'Prescription',
                        color: AppColors.sleep,
                        onTap: () => showComingSoonSheet(context, title: 'Prescriptions'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OverviewTile(
                        icon: Icons.science_rounded,
                        value: '${d.labResults}',
                        label: 'Lab Results',
                        color: AppColors.heart,
                        onTap: () => showComingSoonSheet(context, title: 'Lab Results'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionHeader(
            title: "Today's Appointments",
            subtitle: d.appointments.isEmpty ? null : 'Showing ${d.appointments.length} of ${d.todayAppointments}',
            actionLabel: 'View all',
            onAction: () => widget.onNavigate(1),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 260),
            child: d.appointments.isEmpty
                ? H360Card(
                    child: Row(
                      children: [
                        Icon(Icons.event_busy_rounded, color: AppColors.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('No appointments today.', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final a in d.appointments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppointmentRow(appointment: a, onTap: () => widget.onNavigate(1)),
                        ),
                    ],
                  ),
          ),
        ];
    }
  }
}