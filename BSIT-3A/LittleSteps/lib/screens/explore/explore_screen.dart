import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/activity.dart';
import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../routing/app_router.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/books_service.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_formatting.dart';
import '../../utils/domain_labels.dart';
import '../../utils/plan_errors.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'activity_detail_screen.dart';
import 'storybooks_section.dart';
import 'widgets/explore_activity_card.dart';
import 'widgets/explore_filter_controls.dart';
import 'widgets/explore_filters_sheet.dart';
import 'widgets/explore_state_notices.dart';

/// Browse provisional learning activities and add one to today's plan.
class ExploreScreen extends StatefulWidget {
  /// Creates an [ExploreScreen].
  const ExploreScreen({
    super.key,
    this.catalogService,
    this.planService,
    this.onPlanAdded,
    this.initialSetting,
    this.settingTriggerKey = 0,
  });

  /// Optional catalog service used by tests or a containing feature.
  final CatalogService? catalogService;

  /// Optional plans service used by tests or a containing feature.
  final PlanService? planService;

  /// Called when an item is added to today's plan.
  final ValueChanged<Activity>? onPlanAdded;

  /// Optional play-space filter (`indoor` or `outdoor`) applied when opening
  /// Explore from a contextual prompt such as Today's weather hint.
  final String? initialSetting;

  /// Incremented by the shell to re-apply [initialSetting] on demand.
  final int settingTriggerKey;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late CatalogService _catalogService;
  late PlanService _planService;
  List<Activity> _activities = const [];
  bool _loading = true;
  bool _offline = false;
  bool _initialLoadStarted = false;
  bool _storybooksSelected = false;
  BookshelfShelf _selectedBookshelf = BookshelfShelf.openLibrary;
  int _savedBookCount = 0;
  String? _errorMessage;
  String? _ageBand;
  String? _domain;
  String? _language;
  String? _setting;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _requestNumber = 0;
  String? _lastChildId;

  @override
  void initState() {
    super.initState();
    _setting = widget.initialSetting;
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settingTriggerKey != oldWidget.settingTriggerKey &&
        widget.initialSetting != null) {
      setState(() {
        _storybooksSelected = false;
        _setting = widget.initialSetting;
      });
      unawaited(_loadActivities());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    _catalogService =
        widget.catalogService ?? CatalogService(apiClient: apiClient);
    _planService = widget.planService ?? PlanService(apiClient: apiClient);

    final activeChild = AuthScope.maybeOf(context)?.activeChild;
    final childChanged = activeChild?.id != _lastChildId;
    if (childChanged) {
      _lastChildId = activeChild?.id;
      _ageBand = normalizeCatalogAgeBandCode(activeChild?.ageBand);
    }
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadActivities());
      });
    }
  }

  Future<void> _loadActivities() async {
    final requestNumber = ++_requestNumber;
    _catalogService.apiClient.isOffline = false;
    setState(() {
      _loading = true;
      _offline = false;
      _errorMessage = null;
    });
    try {
      final activities = await _catalogService.getActivities(
        ageBand: _ageBand,
        domain: _domain,
        language: _language,
        setting: _setting,
      );
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _activities = activities;
        _loading = false;
        _offline = _catalogService.apiClient.isOffline;
      });
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _loading = false;
        _offline =
            error is NoConnectionApiException ||
            error is TimeoutApiException ||
            error is SocketException ||
            error is http.ClientException;
        _errorMessage =
            error is ApiException && error.code == 'SERVICE_UNAVAILABLE'
            ? 'The activity catalog is temporarily unavailable. Try again in a moment.'
            : 'The activity catalog could not be loaded. Try again in a moment.';
      });
    }
  }

  List<Activity> get _visibleActivities {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _activities;
    return _activities.where((activity) {
      final matchesTitle = activity.title.toLowerCase().contains(query);
      final matchesMaterial = activity.materials.any(
        (material) => material.toLowerCase().contains(query),
      );
      return matchesTitle || matchesMaterial;
    }).toList();
  }

  void _changeFilter({
    String? ageBand,
    String? domain,
    String? language,
    String? setting,
    bool updateSetting = false,
  }) {
    setState(() {
      _ageBand = ageBand;
      _domain = domain;
      _language = language;
      if (updateSetting) {
        _setting = setting;
      }
    });
    unawaited(_loadActivities());
  }

  void _resetAllFilters(String? defaultAgeBand) {
    _searchController.clear();
    setState(() {
      _ageBand = defaultAgeBand;
      _domain = null;
      _language = null;
      _setting = null;
      _searchQuery = '';
    });
    unawaited(_loadActivities());
  }

  Future<void> _openMoreFilters(Child? activeChild) async {
    final defaultAgeBand = normalizeCatalogAgeBandCode(activeChild?.ageBand);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: AppSizes.sheetMaxWidth),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => ExploreFiltersSheet(
        initialAgeBand: _ageBand,
        defaultAgeBand: defaultAgeBand,
        selectedLanguage: _language,
        selectedSetting: _setting,
        onAgeBandChanged: (value) =>
            _changeFilter(ageBand: value, domain: _domain, language: _language),
        onLanguageSelected: (language) => _changeFilter(
          ageBand: _ageBand,
          domain: _domain,
          language: language,
        ),
        onSettingSelected: (setting) => _changeFilter(
          ageBand: _ageBand,
          domain: _domain,
          language: _language,
          setting: setting,
          updateSetting: true,
        ),
        onResetFilters: () => _changeFilter(
          ageBand: defaultAgeBand,
          domain: _domain,
          language: null,
          setting: null,
          updateSetting: true,
        ),
      ),
    );
  }

  Future<void> _addToPlan(Activity activity) async {
    final session = AuthScope.maybeOf(context);
    if (session == null || !session.isAuthenticated) {
      Navigator.pushNamed(context, AppRoutes.signIn);
      return;
    }
    final child = session.activeChild;
    if (child == null) {
      Navigator.pushNamed(context, AppRoutes.children);
      return;
    }

    final isCustomNonCatalog =
        activity.type == 'story' ||
        activity.type == 'rhyme' ||
        activity.type == 'custom' ||
        activity.id.startsWith('story-') ||
        activity.id.startsWith('rhyme-') ||
        activity.id.startsWith('custom-');
    final customSnapshot = isCustomNonCatalog
        ? CustomPlanActivity.fromActivity(
            activity,
            sourceLabel: activity.type == 'story'
                ? 'Storybook companion'
                : activity.type == 'rhyme'
                ? 'Read & Sing Together'
                : 'Material adaptation',
          )
        : null;
    try {
      await _planService.addActivityToPlan(
        childId: child.id,
        activityId: activity.id,
        scheduledDate: todayIsoDate(),
        durationMinutes: activity.durationMinutes,
        customActivity: customSnapshot,
      );
      if (!mounted) return;
      widget.onPlanAdded?.call(activity);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Added to today's plan")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatPlanErrorMessage(error, subject: 'the activity')),
        ),
      );
    }
  }

  Widget _buildSectionTabs() {
    return ExploreSectionTabs(
      storybooksSelected: _storybooksSelected,
      selectedShelf: _selectedBookshelf,
      savedBookCount: _savedBookCount,
      onActivities: () => setState(() => _storybooksSelected = false),
      onStorybooks: () => setState(() {
        _storybooksSelected = true;
        _selectedBookshelf = BookshelfShelf.openLibrary;
      }),
      onBookshelf: () => setState(() {
        _storybooksSelected = true;
        _selectedBookshelf = BookshelfShelf.ourBookshelf;
      }),
      onRhymes: () => setState(() {
        _storybooksSelected = true;
        _selectedBookshelf = BookshelfShelf.rhymes;
      }),
    );
  }

  Widget _buildSearchRow(Child? activeChild) {
    final defaultAgeBand = normalizeCatalogAgeBandCode(activeChild?.ageBand);
    final activeFilterCount =
        (_ageBand != defaultAgeBand ? 1 : 0) +
        (_language != null ? 1 : 0) +
        (_setting != null ? 1 : 0);

    return ExploreSearchFilterRow(
      controller: _searchController,
      activeFilterCount: activeFilterCount,
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      onOpenFilters: () => _openMoreFilters(activeChild),
    );
  }

  Widget _buildStorybooksSection(Child? activeChild) {
    return StorybooksSection(
      booksService: BooksService(apiClient: _catalogService.apiClient),
      aiService: AiService(apiClient: _catalogService.apiClient),
      planService: _planService,
      activeChild: activeChild,
      selectedShelf: _selectedBookshelf,
      isOffline: _offline,
      onShelfSelected: (shelf) => setState(() => _selectedBookshelf = shelf),
      onSavedCountChanged: (count) => setState(() => _savedBookCount = count),
      onPlanActivity: _addToPlan,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _visibleActivities;
    final activeChild = AuthScope.maybeOf(context)?.activeChild;
    final ageLabel = _ageBand == null
        ? 'All age bands'
        : ageBandForCode(_ageBand!)?.label ?? _ageBand!;
    final resultCount = activities.length;
    final resultMessage = _ageBand == null
        ? '$resultCount ${resultCount == 1 ? 'activity' : 'activities'}'
        : '$resultCount ${resultCount == 1 ? 'activity' : 'activities'} for $ageLabel';

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout =
              constraints.maxWidth >= AppSizes.twoColumnBreakpoint;
          if (!isWideLayout) {
            return ResponsiveContentBox(
              maxWidth: AppSizes.wideContentMaxWidth,
              child: _buildCompactScrollView(
                context: context,
                activities: activities,
                activeChild: activeChild,
                resultMessage: resultMessage,
              ),
            );
          }

          return ResponsiveContentBox(
            alignment: Alignment.topCenter,
            maxWidth: AppSizes.wideContentMaxWidth,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ScreenHeader(
                    title: 'Explore',
                    subtitle: 'Simple ideas with things you already have.',
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  AdaptiveTwoPane(
                    primary: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTabs(),
                        if (!_storybooksSelected) ...[
                          const SizedBox(height: AppSpacing.space12),
                          _buildSearchRow(activeChild),
                          const SizedBox(height: AppSpacing.space12),
                          ExploreDomainFilters(
                            domains: AppDomains.labels,
                            selectedDomain: _domain,
                            horizontalPadding: 0,
                            onSelected: (domain) => _changeFilter(
                              ageBand: _ageBand,
                              domain: domain,
                              language: _language,
                            ),
                          ),
                          ..._buildResultsChildren(
                            context: context,
                            activities: activities,
                            activeChild: activeChild,
                            resultMessage: resultMessage,
                            showInlineIdeaHelper: false,
                          ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.space16),
                          _buildStorybooksSection(activeChild),
                        ],
                      ],
                    ),
                    secondary: !_storybooksSelected
                        ? IdeaHelperEntryCard(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.aiSuggest,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactScrollView({
    required BuildContext context,
    required List<Activity> activities,
    required Child? activeChild,
    required String resultMessage,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space16,
            AppSpacing.space16,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ScreenHeader(
                title: 'Explore',
                subtitle: 'Simple ideas with things you already have.',
              ),
              const SizedBox(height: AppSpacing.space16),
              _buildSectionTabs(),
              if (!_storybooksSelected) ...[
                const SizedBox(height: AppSpacing.space12),
                _buildSearchRow(activeChild),
                const SizedBox(height: AppSpacing.space12),
              ],
            ]),
          ),
        ),
        if (!_storybooksSelected) ...[
          SliverToBoxAdapter(
            child: ExploreDomainFilters(
              domains: AppDomains.labels,
              selectedDomain: _domain,
              onSelected: (domain) => _changeFilter(
                ageBand: _ageBand,
                domain: domain,
                language: _language,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildResultsChildren(
                  context: context,
                  activities: activities,
                  activeChild: activeChild,
                  resultMessage: resultMessage,
                  showInlineIdeaHelper: true,
                ),
              ),
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space24,
          ),
          sliver: SliverToBoxAdapter(
            child: Visibility(
              visible: _storybooksSelected,
              maintainState: true,
              child: _buildStorybooksSection(activeChild),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResultsChildren({
    required BuildContext context,
    required List<Activity> activities,
    required Child? activeChild,
    required String resultMessage,
    required bool showInlineIdeaHelper,
  }) {
    final defaultAgeBand = normalizeCatalogAgeBandCode(activeChild?.ageBand);
    final hasCustomFilter =
        _ageBand != defaultAgeBand ||
        _language != null ||
        _setting != null ||
        _domain != null ||
        _searchQuery.trim().isNotEmpty;
    final summaryParts = <String>[
      resultMessage,
      if (_language != null) AppLanguages.labels[_language] ?? _language!,
      if (_setting != null) formatSettingLabel(_setting!),
    ];
    final activeSummary = summaryParts.join(' · ');

    return [
      const SizedBox(height: AppSpacing.space8),
      if (_offline) const OfflineCatalogNotice(),
      if (_errorMessage != null) ...[
        Semantics(
          liveRegion: true,
          child: CatalogErrorNotice(
            message: _errorMessage!,
            onRetry: _loadActivities,
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
      ],
      if (!_loading && _errorMessage == null)
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  activeSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (hasCustomFilter)
              TextButton(
                onPressed: () => _resetAllFilters(defaultAgeBand),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space8,
                  ),
                ),
                child: const Text('Reset'),
              ),
          ],
        ),
      if (showInlineIdeaHelper && !_loading && _errorMessage == null) ...[
        const SizedBox(height: AppSpacing.space8),
        CompactIdeaHelperBar(
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiSuggest),
        ),
      ],
      if (_loading) ...[
        const SizedBox(height: AppSpacing.space8),
        Semantics(
          liveRegion: true,
          label: 'Loading activities',
          child: const Text('Loading activities…'),
        ),
        const SizedBox(height: AppSpacing.space8),
        const ActivityLoadingSkeleton(),
        const ActivityLoadingSkeleton(),
      ],
      if (!_loading && _errorMessage == null && activities.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.space16),
          child: EmptyStateView(
            title: 'No activities found matching your filters',
            message: _activities.isEmpty
                ? 'Try another age band or filter. New catalog activities will appear here when available.'
                : 'Try another activity or material search.',
            icon: Icons.search_off_outlined,
            actionLabel: 'Clear filters',
            announce: true,
            onAction: () => _resetAllFilters(defaultAgeBand),
          ),
        ),
      if (!_loading && _errorMessage == null)
        ...activities.map(
          (activity) => Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.space12,
              bottom: AppSpacing.space4,
            ),
            child: ExploreActivityCard(
              activity: activity,
              domainLabel: friendlyDomainLabel(activity.domain),
              onAdd: () => _addToPlan(activity),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ActivityDetailScreen(
                    activity: activity,
                    onAddToPlan: _addToPlan,
                  ),
                ),
              ),
              onAdapt: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ActivityDetailScreen(
                    activity: activity,
                    startInAdaptMode: true,
                    onAddToPlan: _addToPlan,
                  ),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.space24),
    ];
  }
}
