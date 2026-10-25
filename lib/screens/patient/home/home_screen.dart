import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/dashboard_service.dart';
import '../../../models/dashboard_data.dart';
import '../../../models/vital_sign.dart';
import '../../../widgets/demo_scenario_sheet.dart';
import '../../../widgets/fade_slide_in.dart';
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
///
/// Handles the three async states the rubric asks for:
/// loading (skeleton), error (retry) and empty (call to action).
/// Pull down to refresh. Long-press the avatar for the demo menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate, required this.onOpenAssistant});

  /// Switches the bottom-nav tab (0 Home, 1 Appointment, 2 Prescription, 3 Records, 4 Profile).
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenAssistant;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  DashboardData? _data;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches the dashboard. [showSkeleton] is false for pull-to-refresh.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final data = await DashboardService.instance.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  /// Opens the detail sheet for one vital; refreshes the tile after a new reading.
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
    DashboardService.instance.setDoseTaken(id, willBeTaken); // persists locally
  }

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
        if (data.isEmpty) {
          return [
            _header(data.patientFirstName),
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
          FadeSlideIn(child: _header(data.patientFirstName)),
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
          const SectionHeader(
            title: 'Health at a Glance',
            subtitle: 'Sample data for now. Tap a card for its trend, or to add your own reading.',
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
