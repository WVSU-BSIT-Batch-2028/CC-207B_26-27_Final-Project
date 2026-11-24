import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/dashboard_data.dart';
import '../../../models/user_role.dart';
import '../../../models/vital_sign.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/profile_service.dart';
import '../../../widgets/demo_scenario_sheet.dart';
import '../../../widgets/fade_slide_in.dart';
import '../../../widgets/notifications_preview.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/state_views.dart';
import 'widgets/assistant_promo_card.dart';
import 'widgets/greeting_header.dart';
import 'widgets/medication_checklist.dart';
import 'widgets/next_appointment_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/vital_detail_sheet.dart';
import 'widgets/vital_tile.dart';

enum _LoadStatus { loading, ready, error }

/// Patient Home / Dashboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenAssistant,
    this.refreshToken = 0,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenAssistant;

  /// Changed by PatientShell when Home should reload quietly (the patient
  /// came back to the Home tab, or marked a dose taken from a reminder).
  /// Home stays alive in the tab stack, so without this it would keep
  /// showing what it loaded first (e.g. not a prescription added later).
  final int refreshToken;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  DashboardData? _data;
  String? _userFirstName;
  String _error = '';

  /// Bumped on every load, so the Notifications card reloads with Home.
  int _loadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reload without the skeleton when the shell asks for fresh data.
  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load(showSkeleton: false);
    }
  }

  /// Fetches the dashboard and signed-in user's name.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    _loadCount++;
    try {
      final results = await Future.wait([
        DashboardService.instance.fetchDashboard(),
        ProfileService.instance.load(UserRole.patient),
      ]);
      if (!mounted) return;
      final data = results[0] as DashboardData;
      final profile = results[1] as dynamic;
      final fullName = (profile.fullName as String).trim();
      // No name yet: the greeting shows without one ("Good Morning").
      final firstName =
          fullName.isEmpty ? null : fullName.split(RegExp(r'\s+')).first;

      setState(() {
        _data = data;
        _userFirstName = firstName;
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

  void _openVital(VitalSign vital) {
    showVitalDetailSheet(
      context,
      vital: vital,
      onChanged: (updated) {
        final current = _data;
        if (current == null || !mounted) return;
        setState(() => _data = current.withVital(updated));
      },
    );
  }

  void _toggleDose(String id) {
    final current = _data;
    if (current == null) return;
    final willBeTaken = !current.doses.firstWhere((d) => d.id == id).taken;
    setState(() => _data = current.withDoseToggled(id));
    DashboardService.instance.setDoseTaken(id, willBeTaken);
  }

  /// Long-press the avatar: switch the data between Normal / Empty / Error
  /// to show each state in the presentation.
  void _openDemoMenu() => showDemoScenarioSheet(context, _load);

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

  Widget _header(String? name) => GreetingHeader(
        name: name,
        onAvatarTap: () => widget.onNavigate(4),
        onAvatarLongPress: _openDemoMenu,
      );

  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.lg);

    switch (_status) {
      case _LoadStatus.loading:
        return [_header(null), gap, const DashboardSkeleton()];

      case _LoadStatus.error:
        return [
          _header(null),
          ErrorState(message: _error, onRetry: _load),
        ];

      case _LoadStatus.ready:
        final data = _data!;
        final displayName = _userFirstName;

        if (data.isEmpty) {
          return [
            _header(displayName),
            EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Your health space is ready',
              message: 'Once you book a consultation or add a prescription, your summary will appear here.',
              actionLabel: 'Book your first appointment',
              onAction: () => widget.onNavigate(1),
            ),
          ];
        }

        return [
          FadeSlideIn(child: _header(displayName)),
          gap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: data.nextAppointment == null
                ? NoAppointmentCard(onBook: () => widget.onNavigate(1))
                : NextAppointmentCard(
                    appointment: data.nextAppointment!,
                    onViewDetails: () => widget.onNavigate(1),
                  ),
          ),
          gap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: QuickActions(
              onBook: () => widget.onNavigate(1),
              onRefill: () => widget.onNavigate(2),
              onRecords: () => widget.onNavigate(3),
              onAskAi: widget.onOpenAssistant,
            ),
          ),
          // Notifications: what is new, with "Mark as done".
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: NotificationsPreview(role: UserRole.patient, refreshToken: _loadCount),
          ),
          const SectionHeader(
            title: 'Health at a Glance',
            subtitle: 'Sample data plus your own readings. Tap a card for its trend, or to add a reading.',
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 240),
            child: VitalsGrid(vitals: data.vitals, onTap: _openVital),
          ),
          SectionHeader(
            title: "Today's Medications",
            actionLabel: 'See all',
            onAction: () => widget.onNavigate(2),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 320),
            child: MedicationChecklist(doses: data.doses, onToggle: _toggleDose),
          ),
          gap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: AssistantPromoCard(onTap: widget.onOpenAssistant),
          ),
        ];
    }
  }
}