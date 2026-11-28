import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../models/milestone.dart';
import '../../models/plan.dart';
import '../../models/weather.dart';
import '../../routing/app_router.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/accessibility.dart';
import '../../utils/date_formatting.dart';
import '../../utils/domain_labels.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/weather_hint_banner.dart';
import 'widgets/today_activity_card.dart';
import 'widgets/today_sections.dart';
import 'widgets/today_side_cards.dart';

/// Interaction states displayed by [TodayScreen].
enum TodayViewState {
  /// Initial network request is in flight.
  loading,

  /// Planned activities are loaded and displayed.
  ready,

  /// Zero activities are scheduled for the selected date.
  empty,

  /// A recoverable request error occurred.
  error,

  /// Cached activities are displayed while offline.
  offline,
}

/// In-memory store recording whether the non-diagnostic advisory was dismissed.
class TodayAdvisoryStorage {
  static final Set<String> _seenKeys = <String>{};

  /// Whether the advisory has been dismissed for [userKey].
  static bool hasSeen(String userKey) => _seenKeys.contains(userKey);

  /// Marks the advisory as dismissed for [userKey].
  static void markSeen(String userKey) => _seenKeys.add(userKey);

  /// Clears recorded dismissals for test isolation.
  static void reset() => _seenKeys.clear();
}

/// Today tab presenting planned play activities, completion status, and weather hints.
class TodayScreen extends StatefulWidget {
  /// Creates a [TodayScreen] with optional service and state overrides.
  const TodayScreen({
    super.key,
    this.planService,
    this.catalogService,
    this.initialState,
    this.initialPlans,
    this.initialActivities,
    this.initialWeatherHint,
    this.initialMilestoneCues,
    this.activeChild,
    this.initialDate,
    this.isOffline = false,
    this.onNavigateTab,
    this.onOpenIdeaHelper,
    this.planRefreshKey = 0,
  });

  /// Optional plan service override for managing activity plans.
  final PlanService? planService;

  /// Optional catalog service override for activity details and weather hints.
  final CatalogService? catalogService;

  /// Optional forced initial view state for widget tests.
  final TodayViewState? initialState;

  /// Optional initial list of planned items for widget tests.
  final List<PlanItem>? initialPlans;

  /// Optional lookup map of activity metadata for widget tests.
  final Map<String, Activity>? initialActivities;

  /// Optional weather hint override for widget tests.
  final WeatherHint? initialWeatherHint;

  /// Optional preloaded milestone cue titles for widget tests.
  final List<String>? initialMilestoneCues;

  /// Currently selected active child profile.
  final Child? activeChild;

  /// Calendar date for which the plan is viewed.
  final DateTime? initialDate;

  /// Whether offline mode is simulated or active.
  final bool isOffline;

  /// Optional callback invoked to switch to another tab in the app shell.
  final ValueChanged<int>? onNavigateTab;

  /// Optional callback invoked with the suggested play setting (`indoor` or
  /// `outdoor`) when the caregiver taps the weather hint play-idea CTA.
  ///
  /// When omitted, [TodayScreen] navigates to [AppRoutes.aiSuggest] with the
  /// recommended setting preselected.
  final ValueChanged<String>? onOpenIdeaHelper;

  /// Incremented when another tab adds a plan item.
  final int planRefreshKey;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late TodayViewState _viewState;
  late DateTime _currentDate;
  late bool _isOffline;

  List<PlanItem> _plans = [];
  Map<String, Activity> _activityLookup = {};
  List<String> _milestoneCues = const [];
  WeatherHint? _weatherHint;
  String? _errorMessage;

  bool _filterUnder10Mins = false;
  bool _filterNoMaterials = false;
  String? _selectedSettingFilter;
  bool _advisorySeen = false;
  bool _weatherDismissed = false;
  bool _initialLoadStarted = false;
  String? _loadedChildId;
  String? _loadedWeatherCityKey;

  Child? get _resolvedChild =>
      widget.activeChild ?? AuthScope.maybeOf(context)?.activeChild;

  String? get _activeChildIdOrNull {
    final resolved = _resolvedChild;
    if (resolved != null) return resolved.id;
    // Preserve standalone widget-test fallback when no AuthScope is mounted.
    if (AuthScope.maybeOf(context) == null) return 'c-maya-default';
    return null;
  }

  String get _effectiveChildId => _activeChildIdOrNull ?? 'c-maya-default';

  String get _childName => _resolvedChild?.nickname ?? 'Maya';

  String get _greetingSubtitle {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return "$greeting! Here's $_childName's play plan for today.";
  }

  void _openFindIdea() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      Navigator.pushNamed(context, AppRoutes.aiSuggest);
    }
  }

  String get _advisoryKey => 'advisory_$_effectiveChildId';

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
    _isOffline = widget.isOffline;
    if (widget.activeChild != null) {
      _advisorySeen = TodayAdvisoryStorage.hasSeen(_advisoryKey);
    }

    if (widget.initialActivities != null) {
      _activityLookup = Map.from(widget.initialActivities!);
    }
    if (widget.initialWeatherHint != null) {
      _weatherHint = widget.initialWeatherHint;
    }
    if (widget.initialMilestoneCues != null) {
      _milestoneCues = List.of(widget.initialMilestoneCues!);
    }
    if (widget.initialPlans != null) {
      _plans = List.from(widget.initialPlans!);
    }

    if (widget.initialState != null) {
      _viewState = widget.initialState!;
    } else if (widget.initialPlans != null) {
      _viewState = _plans.isEmpty ? TodayViewState.empty : TodayViewState.ready;
    } else {
      _viewState = _isOffline ? TodayViewState.offline : TodayViewState.loading;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _advisorySeen = TodayAdvisoryStorage.hasSeen(_advisoryKey);
    _syncActiveChildIfNeeded();
    _syncWeatherLocationIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialActivities != widget.initialActivities) {
      _activityLookup.addAll(widget.initialActivities ?? const {});
    }
    if (oldWidget.activeChild?.id != widget.activeChild?.id) {
      _advisorySeen = TodayAdvisoryStorage.hasSeen(_advisoryKey);
      _syncActiveChildIfNeeded();
    }
    if (oldWidget.planRefreshKey != widget.planRefreshKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTodayPlan();
      });
    }
  }

  // Single entry point for initial load and child switches so IndexedStack
  // refreshes plans whenever the active child changes or is removed.
  void _syncActiveChildIfNeeded() {
    if (widget.initialPlans != null || widget.initialState != null) {
      return;
    }
    final nextChildId = _activeChildIdOrNull;
    final childChanged = nextChildId != _loadedChildId;
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      _loadedChildId = nextChildId;
      if (childChanged) {
        _plans = [];
        _milestoneCues = const [];
        _filterUnder10Mins = false;
        _filterNoMaterials = false;
        _selectedSettingFilter = null;
      }
      if (nextChildId == null) {
        _viewState = TodayViewState.empty;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedChildId == nextChildId) {
          _loadTodayPlan(childIdOverride: nextChildId);
        }
      });
    }
  }

  // Refreshes only the weather hint when the caregiver changes the Settings
  // city or toggles weather hints off, without reloading the Today plan list.
  void _syncWeatherLocationIfNeeded() {
    final session = AuthScope.maybeOf(context);
    if (session == null) return;
    final weatherLocation = session.weatherLocation;
    final nextKey = weatherLocation?.name ?? '__off__';
    if (_loadedWeatherCityKey == null) {
      _loadedWeatherCityKey = nextKey;
      return;
    }
    if (_loadedWeatherCityKey == nextKey) return;

    _loadedWeatherCityKey = nextKey;
    _weatherDismissed = false;
    if (weatherLocation == null) {
      _weatherHint = null;
      return;
    }
    final targetLocation = weatherLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedWeatherCityKey == nextKey) {
        _refreshWeatherHint(targetLocation, expectedCityKey: nextKey);
      }
    });
  }

  Future<void> _refreshWeatherHint(
    WeatherLocation location, {
    required String expectedCityKey,
  }) async {
    try {
      final hint = await _resolveCatalogService().getWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted || _loadedWeatherCityKey != expectedCityKey) return;
      setState(() {
        _weatherHint = hint;
      });
    } catch (_) {
      // Keep the Today plan usable when an optional weather refresh fails.
    }
  }

  ApiClient _resolveApiClient() {
    return widget.planService?.apiClient ??
        AuthScope.apiClientOrDefault(context);
  }

  PlanService _resolvePlanService() {
    return widget.planService ??
        PlanService(apiClient: AuthScope.apiClientOrDefault(context));
  }

  CatalogService _resolveCatalogService() {
    return widget.catalogService ??
        CatalogService(apiClient: AuthScope.apiClientOrDefault(context));
  }

  void _announce(String message) => announceForAccessibility(context, message);

  Future<void> _loadTodayPlan({String? childIdOverride}) async {
    final targetChildId = childIdOverride ?? _activeChildIdOrNull;
    if (targetChildId == null) {
      if (!mounted) return;
      setState(() {
        _plans = [];
        _viewState = TodayViewState.empty;
      });
      return;
    }
    _loadedChildId = targetChildId;

    if (_isOffline) {
      setState(() {
        _viewState = TodayViewState.offline;
      });
      _announce('Working offline. Planned activities for today.');
      return;
    }

    setState(() {
      _viewState = TodayViewState.loading;
      _errorMessage = null;
    });

    final planService = _resolvePlanService();
    final catalogService = _resolveCatalogService();
    final dateString = formatIsoDate(_currentDate);
    final session = AuthScope.maybeOf(context);
    final weatherLocation = session != null
        ? session.weatherLocation
        : WeatherLocation.iloiloCity;
    final requestedWeatherKey = weatherLocation?.name ?? '__off__';
    _loadedWeatherCityKey = requestedWeatherKey;
    final milestoneAgeBand = milestoneAgeBandForCode(_resolvedChild?.ageBand);

    try {
      final results = await Future.wait([
        planService.getPlans(targetChildId, date: dateString),
        if (weatherLocation != null)
          catalogService.getWeather(
            latitude: weatherLocation.latitude,
            longitude: weatherLocation.longitude,
          )
        else
          Future<WeatherHint?>.value(null),
        catalogService
            .getMilestones(ageBand: milestoneAgeBand, limit: 3)
            .catchError((_) => const <MilestonePrompt>[]),
      ]);

      final fetchedPlans = results[0] as List<PlanItem>;
      final fetchedWeather = results[1] as WeatherHint?;
      final fetchedMilestones = results[2] as List<MilestonePrompt>;

      for (final plan in fetchedPlans) {
        if (plan.customActivity != null) {
          _activityLookup[plan.activityId] = plan.customActivity!.toActivity(
            plan.activityId,
          );
          continue;
        }
        if (!_activityLookup.containsKey(plan.activityId)) {
          try {
            final act = await catalogService.getActivityById(plan.activityId);
            _activityLookup[act.id] = act;
          } catch (_) {}
        }
      }

      // Discard stale responses if the caregiver switched children mid-request.
      if (!mounted || targetChildId != _loadedChildId) return;

      final isClientOffline = _resolveApiClient().isOffline;

      setState(() {
        _plans = fetchedPlans;
        _milestoneCues = fetchedMilestones
            .map((prompt) => prompt.title)
            .where((title) => title.isNotEmpty)
            .take(3)
            .toList();
        if (_loadedWeatherCityKey == requestedWeatherKey) {
          _weatherHint = fetchedWeather;
        }
        _isOffline = _isOffline || isClientOffline;
        _viewState = fetchedPlans.isEmpty
            ? TodayViewState.empty
            : TodayViewState.ready;
      });
    } on NoConnectionApiException {
      if (!mounted || targetChildId != _loadedChildId) return;
      setState(() {
        _viewState = TodayViewState.offline;
        _isOffline = true;
      });
      _announce('Working offline. Planned activities for today.');
    } on ApiException catch (e) {
      if (!mounted || targetChildId != _loadedChildId) return;
      setState(() {
        _viewState = TodayViewState.error;
        if (e.statusCode == 404 ||
            e.code == 'RESOURCE_NOT_FOUND' ||
            e.code == 'NOT_FOUND') {
          _errorMessage = "This activity isn't available anymore. It was taken off our list. The rest of your plan is still here.";
        } else {
          _errorMessage = e.message;
        }
      });
      _announce(_errorMessage ?? 'An error occurred loading today plan');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _viewState = _isOffline ? TodayViewState.offline : TodayViewState.error;
        _errorMessage =
            'Unable to connect. Please check your network and try again.';
      });
      _announce('Unable to connect. Working offline.');
    }
  }

  Future<void> _markComplete(PlanItem plan, Activity activity) async {
    if (_isOffline || _resolveApiClient().isOffline) {
      _announce("This activity wasn't marked complete");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This activity wasn't marked complete"),
          duration: AppMotion.snackbarDefault,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final previousIndex = _plans.indexWhere((p) => p.id == plan.id);
    if (previousIndex == -1) return;

    final updatedPlan = PlanItem(
      id: plan.id,
      childId: plan.childId,
      activityId: plan.activityId,
      scheduledDate: plan.scheduledDate,
      status: PlanItem.statusCompleted,
      completedAt: DateTime.now(),
      durationMinutes: plan.durationMinutes,
      feedbackNote: plan.feedbackNote,
      customActivity: plan.customActivity,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _plans[previousIndex] = updatedPlan;
    });

    try {
      await _resolvePlanService().updatePlanStatus(
        childId: _effectiveChildId,
        planId: plan.id,
        status: PlanItem.statusCompleted,
      );

      _announce('${activity.title} marked complete');
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${activity.title} marked complete'),
          duration: AppMotion.snackbarUndo,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.cream,
            onPressed: () => _undoComplete(plan, activity),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plans[previousIndex] = plan;
      });
      _announce("This activity wasn't marked complete");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This activity wasn't marked complete"),
          duration: AppMotion.snackbarDefault,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _undoComplete(PlanItem plan, Activity activity) async {
    final targetIndex = _plans.indexWhere((p) => p.id == plan.id);
    if (targetIndex == -1) return;

    final restoredPlan = PlanItem(
      id: plan.id,
      childId: plan.childId,
      activityId: plan.activityId,
      scheduledDate: plan.scheduledDate,
      status: PlanItem.statusPlanned,
      completedAt: null,
      durationMinutes: plan.durationMinutes,
      feedbackNote: plan.feedbackNote,
      customActivity: plan.customActivity,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _plans[targetIndex] = restoredPlan;
    });

    try {
      await _resolvePlanService().updatePlanStatus(
        childId: _effectiveChildId,
        planId: plan.id,
        status: PlanItem.statusPlanned,
      );
      _announce('Completion undone for ${activity.title}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not undo completion. Please try again.'),
          duration: AppMotion.snackbarDefault,
        ),
      );
    }
  }

  void _dismissAdvisory() {
    setState(() {
      _advisorySeen = true;
    });
    TodayAdvisoryStorage.markSeen(_advisoryKey);
    _announce('Advisory minimized. Persistent link available.');
  }

  void _showAdvisoryDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Not a diagnostic tool'),
          content: const SingleChildScrollView(
            child: Text(
              'Not a diagnostic tool. Observational play suggestions only. You know your child best. Every child develops at their own pace with unique milestones.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _filterUnder10Mins = false;
      _filterNoMaterials = false;
      _selectedSettingFilter = null;
    });
    _announce('All activity filters cleared');
  }

  Future<void> _openWeatherIdeaHelper(String setting) async {
    final settingLabel = setting == PlaySetting.either
        ? 'play'
        : formatSettingLabel(setting).toLowerCase();
    _announce('Opening Idea helper for $settingLabel ideas');
    if (widget.onOpenIdeaHelper != null) {
      widget.onOpenIdeaHelper!(setting);
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.aiSuggest, arguments: setting);
    if (mounted && widget.initialPlans == null && widget.initialState == null) {
      await _loadTodayPlan();
    }
  }

  List<PlanItem> _getFilteredPlans() {
    return _plans.where((plan) {
      final activity = _activityLookup[plan.activityId];
      if (activity == null) return true;

      if (_filterUnder10Mins && activity.durationMinutes > 10) {
        return false;
      }

      if (_filterNoMaterials) {
        final hasMaterials = activity.materials.any(
          (m) => m.trim().isNotEmpty && m.toLowerCase() != 'none',
        );
        if (hasMaterials) return false;
      }

      final setting = activity.setting.toLowerCase();
      if (_selectedSettingFilter != null &&
          setting != _selectedSettingFilter &&
          setting != PlaySetting.either) {
        return false;
      }

      return true;
    }).toList();
  }

  Activity _resolveActivityForPlan(PlanItem plan) {
    return plan.customActivity?.toActivity(plan.activityId) ??
        _activityLookup[plan.activityId] ??
        Activity(
          id: plan.activityId,
          title: 'Scheduled activity',
          type: 'activity',
          language: AppLanguages.english,
          domain: AppDomains.language,
          ageBand: '0-5y',
          durationMinutes: plan.durationMinutes ?? 10,
          durationEstimate: '${plan.durationMinutes ?? 10} mins',
          setting: PlaySetting.indoor,
          materials: const [],
          instructions: const [],
          limitations: '',
          status: Activity.statusSourceChecked,
          provenanceSource: 'LittleSteps',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isOffline || _viewState == TodayViewState.offline)
              const OfflineBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_viewState) {
      case TodayViewState.loading:
        return const LoadingView(message: "Loading today's plan...");
      case TodayViewState.error:
        return ErrorView(
          message: _errorMessage ?? 'Something went wrong loading today plan.',
          onRetry: _loadTodayPlan,
        );
      case TodayViewState.empty:
      case TodayViewState.offline:
      case TodayViewState.ready:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    final isEmptyState = _viewState == TodayViewState.empty;
    final filteredPlans = isEmptyState
        ? const <PlanItem>[]
        : _getFilteredPlans();
    final hasActiveFilters =
        _filterUnder10Mins ||
        _filterNoMaterials ||
        _selectedSettingFilter != null;
    final completedCount = isEmptyState
        ? 0
        : _plans.where((plan) => plan.isCompleted).length;
    final hint = _weatherHint;
    final showWeather =
        !_weatherDismissed &&
        hint != null &&
        hint.hint != null &&
        !hint.isUnavailable;

    final sideCards = TodaySideCards(
      childName: _childName,
      milestoneCues: _milestoneCues,
      onOpenReflection: widget.onNavigateTab != null
          ? () => widget.onNavigateTab!(4)
          : null,
      onOpenMilestones: widget.onNavigateTab != null
          ? () => widget.onNavigateTab!(2)
          : null,
    );

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$_childName's plan for today",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (!isEmptyState) ...[
          const SizedBox(height: AppSpacing.space8),
          TodayQuickFilterChips(
            under10Mins: _filterUnder10Mins,
            noMaterials: _filterNoMaterials,
            selectedSetting: _selectedSettingFilter,
            onUnder10MinsChanged: (selected) {
              setState(() => _filterUnder10Mins = selected);
              _announce(
                selected
                    ? 'Filtered to under 10 minutes'
                    : 'Under 10 minutes filter removed',
              );
            },
            onNoMaterialsChanged: (selected) {
              setState(() => _filterNoMaterials = selected);
              _announce(
                selected
                    ? 'Filtered to no materials needed'
                    : 'No materials filter removed',
              );
            },
            onSettingChanged: (setting) {
              final previous = _selectedSettingFilter;
              setState(() => _selectedSettingFilter = setting);
              if (setting != null) {
                final label = formatSettingLabel(setting).toLowerCase();
                _announce('Filtered to $label activities');
              } else if (previous != null) {
                final label = formatSettingLabel(previous);
                _announce('$label filter removed');
              }
            },
          ),
        ],
        const SizedBox(height: AppSpacing.space12),
        if (!isEmptyState && filteredPlans.isEmpty && hasActiveFilters)
          TodayEmptyFilterState(onClearFilters: _clearFilters)
        else if (isEmptyState || _plans.isEmpty)
          TodayEmptyPlanCard(onFindIdea: _openFindIdea)
        else
          ...filteredPlans.map((plan) {
            final activity = _resolveActivityForPlan(plan);
            return TodayActivityCard(
              plan: plan,
              activity: activity,
              onCompleteToggle: () => _markComplete(plan, activity),
            );
          }),
        SizedBox(
          height: isEmptyState ? AppSpacing.space24 : AppSpacing.space20,
        ),
        TodayHistorySection(
          childName: _childName,
          completedCount: completedCount,
        ),
      ],
    );

    return RefreshIndicator(
      onRefresh: _loadTodayPlan,
      color: AppColors.forest,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'Today', subtitle: _greetingSubtitle),
              const SizedBox(height: AppSpacing.space12),
              TodayAdvisorySection(
                advisorySeen: _advisorySeen,
                onDismiss: _dismissAdvisory,
                onShowDialog: _showAdvisoryDialog,
              ),
              const SizedBox(height: AppSpacing.space12),
              if (showWeather)
                WeatherHintBanner(
                  hint: hint,
                  margin: const EdgeInsets.only(bottom: AppSpacing.space16),
                  onDismiss: () => setState(() => _weatherDismissed = true),
                  onFindIdeas: _openWeatherIdeaHelper,
                ),
            ],
          ),
          AdaptiveTwoPane(primary: mainColumn, secondary: sideCards),
        ],
      ),
    );
  }
}
