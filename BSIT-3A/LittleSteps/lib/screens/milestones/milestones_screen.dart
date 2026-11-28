import 'package:flutter/material.dart';

import '../../models/age_band.dart';
import '../../models/milestone.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/milestones_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/advisory_banner.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'observation_form_sheet.dart';
import 'widgets/milestone_prompt_card.dart';
import 'widgets/milestone_widgets.dart';

/// View states for the milestones screen.
enum MilestonesViewState {
  /// Prompts and saved observations are displayed.
  ready,

  /// Observations are loading from the backend.
  loading,

  /// Zero prompts match the active filters.
  empty,

  /// A recoverable request error occurred.
  error,

  /// Cached observations are displayed while offline.
  offline,
}

/// Milestones tab displaying developmental observation prompts grouped by ECCD domain.
class MilestonesScreen extends StatefulWidget {
  /// Creates a [MilestonesScreen].
  const MilestonesScreen({
    super.key,
    this.initialState = MilestonesViewState.ready,
    this.prompts = const [],
    this.initialObservations = const {},
    this.milestonesService,
    this.catalogService,
  });

  /// Initial view state override for widget tests.
  final MilestonesViewState initialState;

  /// Optional preloaded observational prompts for tests or previews.
  final List<MilestonePrompt> prompts;

  /// Preloaded observations keyed by milestone prompt identifier.
  final Map<String, MilestoneObservation> initialObservations;

  /// Optional service override for loading and saving observations.
  final MilestonesService? milestonesService;

  /// Optional catalog service override for fetching live milestone prompts.
  final CatalogService? catalogService;

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late MilestonesViewState _currentState;
  late List<MilestonePrompt> _prompts;
  late Map<String, MilestoneObservation> _observations;
  MilestoneDomain? _selectedDomainFilter;
  bool _showAdvisory = true;

  late String _selectedAgeBand;
  String? _lastChildId;
  bool _initialLoadStarted = false;
  bool _promptsLoadStarted = false;

  String get _childName =>
      AuthScope.maybeOf(context)?.activeChild?.nickname ?? 'Maya';

  String? get _childId => AuthScope.maybeOf(context)?.activeChild?.id;

  int get _childAgeMonths {
    final ageBand = AuthScope.maybeOf(context)?.activeChild?.ageBand;
    if (ageBand != null) {
      final match = RegExp(r'\d+').firstMatch(ageBand);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 14;
      }
    }
    return 14;
  }

  String get _childAgeBand => milestoneAgeBandForMonths(_childAgeMonths);

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    _prompts = widget.prompts;
    _observations = Map.from(widget.initialObservations);
    _selectedAgeBand = milestoneAgeBands[1];
  }

  ApiClient _resolveApiClient() {
    return widget.milestonesService?.apiClient ??
        widget.catalogService?.apiClient ??
        AuthScope.apiClientOrDefault(context);
  }

  MilestonesService _resolveMilestonesService() {
    return widget.milestonesService ??
        MilestonesService(apiClient: _resolveApiClient());
  }

  CatalogService _resolveCatalogService() {
    return widget.catalogService ??
        CatalogService(apiClient: _resolveApiClient());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_promptsLoadStarted) {
      _promptsLoadStarted = true;
      _loadCatalogPrompts();
    }
    final childId = _childId;
    final childChanged = childId != _lastChildId;
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      _lastChildId = childId;
      _selectedAgeBand = _childAgeBand;
      if (childChanged && widget.initialObservations.isEmpty) {
        _observations = {};
      }
      _loadObservations(childId);
    }
  }

  Future<void> _loadCatalogPrompts() async {
    final canFetch =
        widget.catalogService != null || AuthScope.maybeOf(context) != null;
    if (!canFetch || widget.prompts.isNotEmpty) return;

    if (_prompts.isEmpty && _currentState == MilestonesViewState.ready) {
      setState(() => _currentState = MilestonesViewState.loading);
    }

    try {
      final fetched = await _resolveCatalogService().getMilestones();
      if (!mounted) return;
      setState(() {
        _prompts = fetched;
        if (_currentState == MilestonesViewState.loading ||
            _currentState == MilestonesViewState.error) {
          _currentState = MilestonesViewState.ready;
        }
      });
    } on NoConnectionApiException {
      if (!mounted) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } on TimeoutApiException {
      if (!mounted) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } catch (_) {
      if (!mounted) return;
      if (_prompts.isEmpty) {
        setState(() => _currentState = MilestonesViewState.error);
      }
    }
  }

  void _retryLoad() {
    setState(() => _currentState = MilestonesViewState.ready);
    if (_prompts.isEmpty) {
      _loadCatalogPrompts();
    }
    _loadObservations(_childId);
  }

  Future<void> _loadObservations(String? childId) async {
    if (childId == null || widget.initialObservations.isNotEmpty) return;
    final session = AuthScope.maybeOf(context);
    final canFetch =
        widget.milestonesService != null || (session?.isAuthenticated ?? false);
    if (!canFetch) return;

    try {
      final fetched = await _resolveMilestonesService().getObservations(
        childId,
      );
      if (!mounted || childId != _lastChildId) return;
      setState(() {
        _observations = {for (final obs in fetched) obs.milestoneId: obs};
      });
    } on NoConnectionApiException {
      if (!mounted || childId != _lastChildId) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } on TimeoutApiException {
      if (!mounted || childId != _lastChildId) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } catch (_) {
      // Keep prompts browsable even if saved observations fail to load.
    }
  }

  void _showAgeBandPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => MilestoneAgeBandPickerSheet(
        ageBands: milestoneAgeBands,
        selectedAgeBand: _selectedAgeBand,
        onSelected: (band) => setState(() => _selectedAgeBand = band),
      ),
    );
  }

  Future<void> _saveObservation(MilestoneObservation observation) async {
    final previous = _observations[observation.milestoneId];
    setState(() {
      _observations[observation.milestoneId] = observation;
    });

    final childId = _childId;
    if (childId == null) return;

    try {
      final service = _resolveMilestonesService();
      if (previous != null &&
          previous.id.isNotEmpty &&
          !previous.id.startsWith('obs-local')) {
        await service.updateObservation(
          childId: childId,
          observationId: previous.id,
          status: observation.status,
          observedDate: observation.observedDate,
          notes: observation.notes,
        );
      } else {
        final created = await service.createObservation(
          childId: childId,
          milestoneId: observation.milestoneId,
          status: observation.status,
          observedDate: observation.observedDate,
          notes: observation.notes,
        );
        if (mounted && childId == _lastChildId) {
          setState(() {
            _observations[observation.milestoneId] = created;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      // Restore the prior local state when persistence fails.
      setState(() {
        if (previous != null) {
          _observations[observation.milestoneId] = previous;
        } else {
          _observations.remove(observation.milestoneId);
        }
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not save observation. Please try again.'),
        ),
      );
    }
  }

  void _openObservationSheet(MilestonePrompt prompt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => ObservationFormSheet(
        prompt: prompt,
        childName: _childName,
        childAgeMonths: _childAgeMonths,
        initialObservation: _observations[prompt.id],
        isOffline: _currentState == MilestonesViewState.offline,
        onRetryOffline: () =>
            setState(() => _currentState = MilestonesViewState.ready),
        onSave: _saveObservation,
      ),
    );
  }

  List<Widget> _buildGroupedPrompts(BuildContext context) {
    final ageBandPrompts = _prompts
        .where((p) => p.ageBand == _selectedAgeBand)
        .toList();

    final filteredPrompts = _selectedDomainFilter == null
        ? ageBandPrompts
        : ageBandPrompts
              .where((p) => p.domain == _selectedDomainFilter)
              .toList();

    final grouped = <MilestoneDomain, List<MilestonePrompt>>{};
    for (final p in filteredPrompts) {
      grouped.putIfAbsent(p.domain, () => []).add(p);
    }

    final widgets = <Widget>[];
    for (final domain in MilestoneDomain.values) {
      final domainPrompts = grouped[domain];
      if (domainPrompts == null || domainPrompts.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
          child: Text(
            domain.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );

      for (final prompt in domainPrompts) {
        widgets.add(
          MilestonePromptCard(
            prompt: prompt,
            observation: _observations[prompt.id],
            onTapAction: () => _openObservationSheet(prompt),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          ScreenHeader(
            title: 'Milestones',
            subtitle: 'Every child develops at their own pace.',
            onAdvisoryTap: !_showAdvisory
                ? () => setState(() => _showAdvisory = true)
                : null,
          ),
          const SizedBox(height: AppSpacing.space12),
          if (_currentState == MilestonesViewState.loading)
            const MilestonesLoadingSkeleton()
          else if (_currentState == MilestonesViewState.error)
            InlineErrorCard(onRetry: _retryLoad)
          else ...[
            if (_currentState == MilestonesViewState.offline)
              OfflineStatusCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.space12),
                message: "Your note wasn't saved. Keep this screen open and tap Retry when you're back online.",
                onRetry: _retryLoad,
              ),
            if (_currentState == MilestonesViewState.empty ||
                _observations.isEmpty)
              const MilestonesEmptyCard(),
            if (_showAdvisory)
              AdvisoryBanner(
                margin: const EdgeInsets.only(bottom: AppSpacing.space12),
                title: 'LittleSteps is not a diagnostic tool',
                message: "LittleSteps shares play ideas and things to look for. It's not a test. Children develop at different rates. Talk to a health professional, like your pediatrician or barangay health worker, if you have concerns.",
                onDismiss: () => setState(() => _showAdvisory = false),
              ),
            MilestoneAgeBandSelector(
              selectedAgeBand: _selectedAgeBand,
              onTap: _showAgeBandPicker,
            ),
            const SizedBox(height: AppSpacing.space12),
            MilestoneDomainFilters(
              selectedDomain: _selectedDomainFilter,
              onSelected: (domain) =>
                  setState(() => _selectedDomainFilter = domain),
            ),
            const SizedBox(height: AppSpacing.space16),
            ..._buildGroupedPrompts(context),
          ],
        ],
      ),
    );
  }
}
