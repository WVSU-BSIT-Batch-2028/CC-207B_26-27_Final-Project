import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/age_band.dart';
import '../../models/summary.dart';
import '../../routing/app_router.dart';
import '../../services/api_client.dart';
import '../../services/milestones_service.dart';
import '../../services/plan_service.dart';
import '../../services/summary_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/domain_labels.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import 'widgets/weekly_summary_controls.dart';
import 'widgets/weekly_summary_populated_view.dart';
import 'widgets/weekly_summary_states.dart';

/// View states for the weekly summary screen.
enum WeeklySummaryViewState {
  /// Weekly summary metrics and reflection card are displayed.
  ready,

  /// Weekly summary data is loading from the backend.
  loading,

  /// A recoverable request error occurred.
  error,

  /// Cached weekly summary data is displayed while offline.
  offline,
}

/// "This week" reflection tab presenting factual weekly summaries for the active child.
class WeeklySummaryScreen extends StatefulWidget {
  /// Creates a [WeeklySummaryScreen].
  const WeeklySummaryScreen({
    super.key,
    this.initialState = WeeklySummaryViewState.ready,
    this.initialWeek = '2026-W43',
    this.summaries,
    this.childName,
    this.childAgeBand,
    this.summaryService,
    this.onFindIdea,
  });

  /// Initial view state override for widget tests.
  final WeeklySummaryViewState initialState;

  /// Initial ISO week identifier selected on load.
  final String initialWeek;

  /// Optional map of preloaded summaries keyed by ISO week.
  final Map<String, WeeklySummary>? summaries;

  /// Optional child nickname override for widget tests.
  final String? childName;

  /// Optional child age-band override for widget tests.
  final String? childAgeBand;

  /// Optional service override for fetching weekly summaries.
  final SummaryService? summaryService;

  /// Optional callback invoked when the caregiver taps "Find a 10-minute idea".
  final VoidCallback? onFindIdea;

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  late WeeklySummaryViewState _currentState;
  late String _selectedWeekId;
  late Map<String, WeeklySummary> _summaries;
  String? _lastChildId;
  bool _initialLoadStarted = false;

  ApiClient _resolveApiClient() {
    return widget.summaryService?.apiClient ??
        AuthScope.apiClientOrDefault(context);
  }

  SummaryService _resolveSummaryService() {
    return widget.summaryService ??
        SummaryService(apiClient: _resolveApiClient());
  }

  String? get _childId => AuthScope.maybeOf(context)?.activeChild?.id;

  String get _childName =>
      AuthScope.maybeOf(context)?.activeChild?.nickname ??
      widget.childName ??
      'Maya';

  String get _childAgeDisplay {
    final activeChild = AuthScope.maybeOf(context)?.activeChild;
    if (activeChild != null) {
      return formatChildAgeLabel(ageBand: activeChild.ageBand);
    }
    return widget.childAgeBand ?? '14 months';
  }

  static String dateToIsoWeek(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return '';
      final date = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final thursday = date.add(
        Duration(days: 4 - (date.weekday == 0 ? 7 : date.weekday)),
      );
      final jan4 = DateTime.utc(thursday.year, 1, 4);
      final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
      final weekNumber =
          1 + ((thursday.difference(week1Monday).inDays) / 7).floor();
      return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static WeeklySummary _createEmptyWeekSummaryForId(String weekId) {
    try {
      final parts = weekId.split('-W');
      final year = int.parse(parts[0]);
      final week = int.parse(parts[1]);

      final jan4 = DateTime.utc(year, 1, 4);
      final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
      final monday = week1Monday.add(Duration(days: (week - 1) * 7));
      final sunday = monday.add(const Duration(days: 6));

      return WeeklySummary(
        id: weekId,
        weekStartDate: DateFormat('yyyy-MM-dd').format(monday),
        weekEndDate: DateFormat('yyyy-MM-dd').format(sunday),
        completedActivityCount: 0,
        observedMilestoneCount: 0,
        totalPlannedActivities: 0,
        domainDistribution: AppDomains.emptyCounts,
        topActivityIds: const [],
        reflectionPrompt: '',
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return WeeklySummary(
        id: weekId,
        weekStartDate: '',
        weekEndDate: '',
        completedActivityCount: 0,
        observedMilestoneCount: 0,
        totalPlannedActivities: 0,
        domainDistribution: const {},
        topActivityIds: const [],
        reflectionPrompt: '',
        generatedAt: DateTime.now(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    if (widget.summaries != null) {
      _selectedWeekId = widget.initialWeek;
      _summaries = widget.summaries!;
    } else {
      _currentState = WeeklySummaryViewState.loading;
      _selectedWeekId = '';
      _summaries = {};
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.summaries != null) {
      _summaries = widget.summaries!;
      _selectedWeekId = widget.initialWeek;
      _currentState = widget.initialState;
      return;
    }
    final childId = _childId;
    final childChanged = childId != _lastChildId;
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      _lastChildId = childId;
      if (childChanged) {
        _summaries = {};
        _selectedWeekId = '';
        _currentState = WeeklySummaryViewState.loading;
      }
      _loadWeeklySummary(null, childId);
    }
  }

  Future<void> _loadWeeklySummary([String? weekId, String? childId]) async {
    final targetChildId = childId ?? _childId;
    if (targetChildId == null) {
      if (mounted) {
        setState(() => _currentState = WeeklySummaryViewState.ready);
      }
      return;
    }

    try {
      final apiClient = _resolveApiClient();
      final summary = await _resolveSummaryService().getWeeklySummary(
        targetChildId,
        week: weekId,
      );
      if (!mounted || targetChildId != _lastChildId) return;

      final updatedSummaries = Map<String, WeeklySummary>.from(_summaries)
        ..[summary.id] = summary;

      // Discover recorded past weeks with activities or milestones.
      try {
        final obsList = await MilestonesService(apiClient: apiClient)
            .getObservations(targetChildId);
        final plansList = await PlanService(apiClient: apiClient)
            .getPlans(targetChildId);

        for (final dateStr in [
          ...obsList.map((o) => o.observedDate),
          ...plansList.map((p) => p.scheduledDate),
        ]) {
          if (dateStr.isEmpty) continue;
          final week = dateToIsoWeek(dateStr);
          if (week.isNotEmpty && !updatedSummaries.containsKey(week)) {
            updatedSummaries[week] = _createEmptyWeekSummaryForId(week);
          }
        }
      } catch (_) {}

      if (!mounted || targetChildId != _lastChildId) return;

      final sortedKeys = updatedSummaries.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      final sortedMap = {
        for (final key in sortedKeys) key: updatedSummaries[key]!,
      };

      setState(() {
        _summaries = sortedMap;
        _selectedWeekId = summary.id;
        _currentState = WeeklySummaryViewState.ready;
      });
    } on NoConnectionApiException {
      if (!mounted || targetChildId != _lastChildId) return;
      setState(() => _currentState = WeeklySummaryViewState.offline);
    } on TimeoutApiException {
      if (!mounted || targetChildId != _lastChildId) return;
      setState(() => _currentState = WeeklySummaryViewState.offline);
    } catch (_) {
      if (!mounted || targetChildId != _lastChildId) return;
      setState(() => _currentState = WeeklySummaryViewState.error);
    }
  }

  WeeklySummary? get _currentSummary => _summaries[_selectedWeekId];

  void _showWeekPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => WeekPickerSheet(
        summaries: _summaries,
        selectedWeekId: _selectedWeekId,
        onSelected: (picked) {
          setState(() => _selectedWeekId = picked);
          if (widget.summaries == null && _childId != null) {
            _loadWeeklySummary(picked);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSummary = _currentSummary;
    final weekLabel =
        currentSummary?.formattedRange ??
        (_selectedWeekId.isNotEmpty ? _selectedWeekId : 'Current week');

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          const ScreenHeader(
            title: 'This week',
            subtitle: 'A look back at the moments you wrote down.',
          ),
          const SizedBox(height: AppSpacing.space12),
          WeeklySummaryChildBadge(
            childName: _childName,
            childAgeDisplay: _childAgeDisplay,
          ),
          const SizedBox(height: AppSpacing.space12),
          WeekSelectorCard(label: weekLabel, onTap: _showWeekPicker),
          const SizedBox(height: AppSpacing.space16),
          if (_currentState == WeeklySummaryViewState.loading)
            const WeeklySummaryLoadingView()
          else if (_currentState == WeeklySummaryViewState.error)
            WeeklySummaryErrorCard(
              onRetry: () =>
                  setState(() => _currentState = WeeklySummaryViewState.ready),
            )
          else if (_currentState == WeeklySummaryViewState.offline) ...[
            WeeklySummaryOfflineBanner(
              onRetry: () =>
                  setState(() => _currentState = WeeklySummaryViewState.ready),
            ),
            if (currentSummary != null && !currentSummary.isEmptyWeek)
              WeeklySummaryPopulatedView(
                childName: _childName,
                summary: currentSummary,
              ),
          ] else if (currentSummary == null || currentSummary.isEmptyWeek)
            WeeklySummaryEmptyCard(
              onFindIdea: () {
                if (widget.onFindIdea != null) {
                  widget.onFindIdea!();
                } else {
                  Navigator.pushNamed(context, AppRoutes.aiSuggest);
                }
              },
            )
          else
            WeeklySummaryPopulatedView(
              childName: _childName,
              summary: currentSummary,
            ),
        ],
      ),
    );
  }
}
