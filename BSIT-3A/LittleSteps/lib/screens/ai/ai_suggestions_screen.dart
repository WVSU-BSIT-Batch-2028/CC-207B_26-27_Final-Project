import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_formatting.dart';
import '../../utils/domain_labels.dart';
import '../../utils/plan_errors.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/state_views.dart';
import 'widgets/ai_idea_form_card.dart';
import 'widgets/ai_results_section.dart';

/// Screen that hosts the Idea Helper play activity recommendation flow.
///
/// Collects available materials, duration, setting, and language preferences
/// to generate non-diagnostic play recommendations with catalog fallback.
class AiSuggestionsScreen extends StatefulWidget {
  /// Creates an [AiSuggestionsScreen].
  const AiSuggestionsScreen({
    super.key,
    this.apiClient,
    this.aiService,
    this.catalogService,
    this.planService,
    this.initialChild,
    this.initialSetting,
  });

  /// Optional HTTP client override used for tests.
  final ApiClient? apiClient;

  /// Optional AI recommendation service override used for tests.
  final AiService? aiService;

  /// Optional catalog service override for weather hints and fallback picks.
  final CatalogService? catalogService;

  /// Optional plan service override for saving suggestions to today's plan.
  final PlanService? planService;

  /// Optional active child override used when launching outside [AuthScope].
  final Child? initialChild;

  /// Optional preselected play setting (`indoor`, `outdoor`, or `either`)
  /// passed from contextual entry points such as Today's weather guidance.
  final String? initialSetting;

  @override
  State<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> {
  static const List<int> _timeOptions = [10, 15, 30, 45];
  static const String _weatherDisabledKey = '__off__';

  final TextEditingController _materialsController = TextEditingController();

  int _timeMinutes = 15;
  String _setting = PlaySetting.either;
  String _language = AppLanguages.english;
  String _ageBand = defaultAgeBandCode;
  String? _domain;
  bool _hasExplicitInitialSetting = false;

  bool _isLoading = false;
  bool _isAddingAll = false;
  final Set<String> _addedActivityIds = {};
  RecommendationResponse? _response;
  String? _rateLimitMessage;
  String? _fallbackNotice;
  WeatherHint? _weatherHint;
  String? _lastWeatherCityKey;
  String? _lastChildId;

  Child? get _effectiveChild =>
      widget.initialChild ?? AuthScope.maybeOf(context)?.activeChild;

  ApiClient _resolveApiClient() {
    return widget.apiClient ?? AuthScope.apiClientOrDefault(context);
  }

  AiService _resolveAiService() {
    return widget.aiService ?? AiService(apiClient: _resolveApiClient());
  }

  CatalogService _resolveCatalogService() {
    return widget.catalogService ??
        CatalogService(apiClient: _resolveApiClient());
  }

  PlanService _resolvePlanService() {
    return widget.planService ?? PlanService(apiClient: _resolveApiClient());
  }

  @override
  void initState() {
    super.initState();
    final initialChild = widget.initialChild;
    if (initialChild != null) {
      _ageBand = initialChild.ageBand;
    }
    final requestedSetting = widget.initialSetting?.toLowerCase();
    if (requestedSetting == PlaySetting.indoor ||
        requestedSetting == PlaySetting.outdoor ||
        requestedSetting == PlaySetting.either) {
      _setting = requestedSetting!;
      _hasExplicitInitialSetting = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync age band only when the active child changes so manual edits survive rebuilds.
    final activeChild = _effectiveChild;
    if (widget.initialChild == null && activeChild?.id != _lastChildId) {
      _lastChildId = activeChild?.id;
      if (activeChild != null) {
        _ageBand = activeChild.ageBand;
      }
    }

    final session = AuthScope.maybeOf(context);
    final weatherLocation = session != null
        ? session.weatherLocation
        : WeatherLocation.iloiloCity;
    final weatherCityKey = weatherLocation?.name ?? _weatherDisabledKey;
    if (_lastWeatherCityKey != weatherCityKey) {
      _lastWeatherCityKey = weatherCityKey;
      if (weatherLocation == null) {
        _weatherHint = null;
      } else {
        _fetchWeatherGuidance(weatherLocation);
      }
    }
  }

  @override
  void dispose() {
    _materialsController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeatherGuidance(WeatherLocation location) async {
    try {
      final hint = await _resolveCatalogService().getWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weatherHint = hint;
        if (!_hasExplicitInitialSetting) {
          if (hint.isIndoorSuggested) {
            _setting = PlaySetting.indoor;
          } else if (hint.isOutdoorSuggested) {
            _setting = PlaySetting.outdoor;
          }
        }
      });
    } catch (_) {}
  }

  List<String> _parseMaterials() {
    return _materialsController.text
        .split(',')
        .map((m) => m.trim().toLowerCase())
        .where((m) => m.isNotEmpty && m.length <= 40)
        .take(10)
        .toList();
  }

  Future<void> _submitRequest() async {
    setState(() {
      _isLoading = true;
      _rateLimitMessage = null;
      _fallbackNotice = null;
    });

    final materials = _parseMaterials();

    try {
      final result = await _resolveAiService()
          .getRecommendations(
            ageBand: _ageBand,
            setting: _setting,
            timeMinutes: _timeMinutes,
            materials: materials,
            language: _language,
            domain: _domain,
            count: 3,
          )
          .timeout(AppMotion.aiRequestTimeout);

      if (!mounted) return;
      var resolved = result;
      if (!resolved.isAiGenerated && resolved.suggestions.isEmpty) {
        final picks = await _catalogPicks();
        if (!mounted) return;
        if (picks.isNotEmpty) {
          resolved = _fallbackResponse(picks);
        }
      }
      setState(() {
        _response = resolved;
        _isLoading = false;
        if (!resolved.isAiGenerated) {
          _fallbackNotice = resolved.suggestions.isNotEmpty
              ? 'AI suggestions are unavailable right now. Here are reviewed play ideas for this age.'
              : 'AI suggestions are unavailable right now, and no matching activities could be loaded.';
        }
      });
      unawaited(_syncTodayPlannedIds());
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429 || e.code == 'RATE_LIMITED') {
        await _handleRateLimit();
      } else {
        await _handleGenericFallback();
      }
    } catch (_) {
      if (!mounted) return;
      await _handleGenericFallback();
    }
  }

  Future<void> _handleRateLimit() async {
    final picks = await _catalogPicks();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _rateLimitMessage = "Let's take a short break. You've asked for many ideas in a row. Please wait a minute, then try again.";
      _response = _fallbackResponse(picks);
    });
  }

  Future<void> _handleGenericFallback() async {
    final picks = await _catalogPicks();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _fallbackNotice = picks.isNotEmpty
          ? 'AI suggestions are unavailable right now. Here are reviewed play ideas for this age.'
          : 'AI suggestions are unavailable right now, and no matching activities could be loaded.';
      _response = _fallbackResponse(picks);
    });
  }

  RecommendationResponse _fallbackResponse(List<Recommendation> picks) {
    return RecommendationResponse(
      suggestions: picks,
      source: 'catalog_fallback',
      tier: 3,
      label: 'Our picks',
      disclaimer:
          'Observational play suggestion only. Not developmental assessment.',
    );
  }

  // Filters catalog picks by age band, setting, and duration, relaxing
  // constraints progressively only when stricter filters return empty.
  Future<List<Recommendation>> _catalogPicks() async {
    try {
      final catalog = _resolveCatalogService();
      var pool = await catalog.getActivities(ageBand: _ageBand);
      if (pool.isEmpty) {
        pool = await catalog.getActivities();
      }
      if (pool.isEmpty) return const [];

      bool matchesSetting(String itemSetting) {
        return _setting == PlaySettingOption.either.code ||
            itemSetting == _setting ||
            itemSetting == PlaySettingOption.either.code;
      }

      var filtered = pool
          .where(
            (a) =>
                matchesSetting(a.setting) && a.durationMinutes <= _timeMinutes,
          )
          .toList();
      if (filtered.isEmpty) {
        filtered = pool.where((a) => matchesSetting(a.setting)).toList();
      }
      if (filtered.isEmpty) {
        filtered = pool;
      }

      return filtered
          .take(3)
          .map(
            (a) => Recommendation(
              activityId: a.id,
              title: a.title,
              whyPicked: 'A reviewed pick for this age from our activity list.',
              activity: a,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _syncTodayPlannedIds() async {
    final childId = _effectiveChild?.id ?? widget.initialChild?.id;
    final session = AuthScope.maybeOf(context);
    final canFetch =
        widget.planService != null ||
        widget.apiClient != null ||
        (session?.isAuthenticated ?? false);
    if (childId == null || !canFetch) return;

    try {
      final plans = await _resolvePlanService().getPlans(
        childId,
        date: todayIsoDate(),
      );
      if (!mounted) return;
      setState(() {
        _addedActivityIds.addAll(plans.map((p) => p.activityId));
      });
    } catch (_) {}
  }

  String _planActivityId(Recommendation item) {
    if (!item.isCustom) return item.activityId;
    final slug = item.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (slug.isEmpty) return 'custom-play-idea';
    final full = 'custom-$slug';
    return full.length <= 64
        ? full
        : full.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
  }

  CustomPlanActivity? _customSnapshotFor(Recommendation item) {
    if (!item.isCustom || item.activity == null) return null;
    return CustomPlanActivity.fromActivity(
      item.activity!,
      sourceLabel: 'Material adaptation',
    );
  }

  String _addToPlanErrorMessage(Object error, {required bool isBatch}) {
    return formatPlanErrorMessage(
      error,
      subject: isBatch ? 'activities' : 'this',
    );
  }

  Future<void> _addToPlan(Recommendation item) async {
    final childId = _effectiveChild?.id ?? widget.initialChild?.id;
    final planActivityId = _planActivityId(item);
    if (childId == null || _addedActivityIds.contains(planActivityId)) return;

    try {
      await _resolvePlanService().addActivityToPlan(
        childId: childId,
        activityId: planActivityId,
        scheduledDate: todayIsoDate(),
        durationMinutes: item.activity?.durationMinutes,
        customActivity: _customSnapshotFor(item),
      );
      if (!mounted) return;
      setState(() => _addedActivityIds.add(planActivityId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${item.title}" to today\'s plan'),
          duration: AppMotion.snackbarDefault,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_addToPlanErrorMessage(error, isBatch: false)),
          duration: AppMotion.snackbarDefault,
        ),
      );
    }
  }

  Future<void> _addAllToPlan(List<Recommendation> suggestions) async {
    final childId = _effectiveChild?.id ?? widget.initialChild?.id;
    if (childId == null || _isAddingAll) return;
    final pending = suggestions
        .where((item) => !_addedActivityIds.contains(_planActivityId(item)))
        .toList();
    if (pending.isEmpty) return;

    setState(() => _isAddingAll = true);
    final today = todayIsoDate();
    final service = _resolvePlanService();
    var addedCount = 0;
    Object? lastError;

    for (final item in pending) {
      final planActivityId = _planActivityId(item);
      try {
        await service.addActivityToPlan(
          childId: childId,
          activityId: planActivityId,
          scheduledDate: today,
          durationMinutes: item.activity?.durationMinutes,
          customActivity: _customSnapshotFor(item),
        );
        addedCount++;
        if (mounted) {
          setState(() => _addedActivityIds.add(planActivityId));
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (!mounted) return;
    setState(() => _isAddingAll = false);
    final message = addedCount > 0
        ? "Added $addedCount ${addedCount == 1 ? 'activity' : 'activities'} to today's plan"
        : lastError != null
        ? _addToPlanErrorMessage(lastError, isBatch: true)
        : "Could not add activities to today's plan. Please try again.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: AppMotion.snackbarDefault),
    );
  }

  void _resetToForm() {
    setState(() {
      _response = null;
      _rateLimitMessage = null;
      _fallbackNotice = null;
      _addedActivityIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final response = _response;
    final weatherCityLabel =
        _lastWeatherCityKey != null &&
            _lastWeatherCityKey != _weatherDisabledKey
        ? _lastWeatherCityKey
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Idea helper')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: ResponsiveContentBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoading)
                  const LoadingView(
                    message: 'Finding ideas… This usually takes a few seconds.',
                  )
                else if (response != null)
                  AiResultsSection(
                    response: response,
                    timeMinutes: _timeMinutes,
                    hasActiveChild: _effectiveChild != null,
                    isAddingAll: _isAddingAll,
                    rateLimitMessage: _rateLimitMessage,
                    fallbackNotice: _fallbackNotice,
                    isAlreadyAdded: (item) =>
                        _addedActivityIds.contains(_planActivityId(item)),
                    onAddToPlan: _addToPlan,
                    onAddAll: () => _addAllToPlan(response.suggestions),
                    onRetry: _submitRequest,
                    onEditPreferences: _resetToForm,
                    onBackToActivities: () => Navigator.of(context).pop(),
                  )
                else
                  AiIdeaFormCard(
                    timeOptions: _timeOptions,
                    selectedTimeMinutes: _timeMinutes,
                    selectedSetting: _setting,
                    selectedAgeBand: _ageBand,
                    selectedLanguage: _language,
                    materialsController: _materialsController,
                    weatherHint: _weatherHint,
                    weatherCityLabel: weatherCityLabel,
                    onTimeChanged: (val) => setState(() => _timeMinutes = val),
                    onSettingChanged: (val) => setState(() => _setting = val),
                    onAgeBandChanged: (val) => setState(() => _ageBand = val),
                    onLanguageChanged: (val) => setState(() => _language = val),
                    onSubmit: _submitRequest,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
