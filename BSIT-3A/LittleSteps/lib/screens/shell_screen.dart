import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/child.dart';
import '../routing/app_router.dart';
import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/auth_session_state.dart';
import '../services/children_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/account_menu_sheet.dart';
import '../widgets/auth_scope.dart';
import '../widgets/brand_logo.dart';
import '../widgets/child_chip.dart';
import '../widgets/no_children_view.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/shell_navigation_sidebar.dart';
import '../widgets/state_views.dart';
import 'account/settings_screen.dart';
import 'explore/explore_screen.dart';
import 'journal/journal_screen.dart';
import 'milestones/milestones_screen.dart';
import 'reflection/weekly_summary_screen.dart';
import 'today/today_screen.dart';

/// Main navigation shell hosting adaptive navigation and the shared app header.
///
/// Uses a bottom [NavigationBar] on compact viewports and switches to a side
/// [ShellNavigationSidebar] at or above [AppSizes.wideLayoutBreakpoint] while
/// keeping tab content centered within [AppSizes.contentMaxWidth].
class ShellScreen extends StatefulWidget {
  /// Creates a [ShellScreen].
  const ShellScreen({
    super.key,
    this.email,
    this.children = const [],
    this.activeChildId,
    this.onChildSelected,
    this.onChildDeleted,
    this.onSignOut,
    this.onAccountDeleted,
    this.accountService,
    this.childrenService,
  });

  /// Optional caregiver email override used in tests.
  final String? email;

  /// Initial list of child profiles shown before fetching from the API.
  final List<Child> children;

  /// Optional active child ID override used in tests.
  final String? activeChildId;

  /// Callback invoked when the caregiver selects a different child profile.
  final ValueChanged<Child>? onChildSelected;

  /// Callback invoked with the child ID after a profile is deleted.
  final ValueChanged<String>? onChildDeleted;

  /// Callback invoked after the caregiver signs out.
  final VoidCallback? onSignOut;

  /// Callback invoked after the caregiver deletes their account.
  final VoidCallback? onAccountDeleted;

  /// Optional account service override passed to [SettingsScreen].
  final AccountService? accountService;

  /// Optional children service override used to load and delete profiles.
  final ChildrenService? childrenService;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const List<ShellDestination> _destinations = [
    ShellDestination(
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
      label: 'Today',
    ),
    ShellDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
    ),
    ShellDestination(
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
      label: 'Milestones',
    ),
    ShellDestination(
      icon: Icons.book_outlined,
      selectedIcon: Icons.book,
      label: 'Journal',
    ),
    ShellDestination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      label: 'This week',
    ),
  ];

  int _currentIndex = 0;
  int _todayPlanRefreshKey = 0;
  List<Child> _children = [];
  Map<String, Activity> _scheduledActivityDetails = {};
  bool _isLoadingChildren = false;

  @override
  void initState() {
    super.initState();
    _children = List.of(widget.children);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshChildren();
  }

  ChildrenService _resolveChildrenService() {
    if (widget.childrenService != null) return widget.childrenService!;
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return ChildrenService(apiClient: apiClient);
  }

  Future<void> _refreshChildren({bool force = false}) async {
    final sessionState = AuthScope.maybeOf(context);
    if (sessionState == null || !sessionState.isAuthenticated) return;
    if (!force && _children.isNotEmpty && sessionState.activeChild != null) {
      return;
    }
    if (_isLoadingChildren) return;

    _isLoadingChildren = true;

    try {
      final fetched = await _resolveChildrenService().getChildren();
      if (!mounted) return;

      setState(() {
        _children = fetched;
        _isLoadingChildren = false;
      });

      final currentActiveId = sessionState.activeChild?.id;
      final stillExists =
          currentActiveId != null &&
          fetched.any((child) => child.id == currentActiveId);
      if (!stillExists) {
        sessionState.setActiveChild(fetched.isNotEmpty ? fetched.first : null);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingChildren = false;
        });
      }
    }
  }

  void _selectDestination(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handlePlanAdded(Activity activity) {
    setState(() {
      _scheduledActivityDetails = {
        ..._scheduledActivityDetails,
        activity.id: activity,
      };
      _todayPlanRefreshKey++;
    });
  }

  Widget _buildAuthGatedTab({
    required bool isAuthenticated,
    required Child? activeChild,
    required Widget noChildView,
    required Widget authenticatedChild,
    required String signInTitle,
    required String signInMessage,
    required IconData signInIcon,
  }) {
    if (!isAuthenticated) {
      return EmptyStateView(
        title: signInTitle,
        message: signInMessage,
        icon: signInIcon,
        actionLabel: 'Sign in',
        onAction: () => Navigator.pushNamed(context, AppRoutes.signIn),
      );
    }
    return activeChild != null ? authenticatedChild : noChildView;
  }

  @override
  Widget build(BuildContext context) {
    final compactHeader =
        MediaQuery.sizeOf(context).width < AppSizes.compactHeaderBreakpoint;
    final sessionState = AuthScope.maybeOf(context);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;
    final activeChild = sessionState?.activeChild;

    final rawEmail = sessionState?.currentUser?.email ?? widget.email;
    final caregiverName = rawEmail != null && rawEmail.contains('@')
        ? rawEmail.split('@').first
        : rawEmail;
    final formattedCaregiver = caregiverName != null && caregiverName.isNotEmpty
        ? '${caregiverName[0].toUpperCase()}${caregiverName.substring(1)}'
        : null;

    final noChildView = NoChildrenView(
      caregiverName: formattedCaregiver,
      onAddChild: () => Navigator.pushNamed(context, AppRoutes.childrenAdd),
    );

    final exploreScreen = ExploreScreen(onPlanAdded: _handlePlanAdded);

    final screens = <Widget>[
      _buildAuthGatedTab(
        isAuthenticated: isAuthenticated,
        activeChild: activeChild,
        noChildView: noChildView,
        authenticatedChild: TodayScreen(
          onNavigateTab: _selectDestination,
          planRefreshKey: _todayPlanRefreshKey,
          initialActivities: _scheduledActivityDetails,
        ),
        signInTitle: "Sign in to see today's plan",
        signInMessage: 'Sign in with your caregiver account to view and plan play activities.',
        signInIcon: Icons.lock_outline,
      ),
      isAuthenticated && activeChild == null ? noChildView : exploreScreen,
      _buildAuthGatedTab(
        isAuthenticated: isAuthenticated,
        activeChild: activeChild,
        noChildView: noChildView,
        authenticatedChild: const MilestonesScreen(),
        signInTitle: 'Sign in to view milestones',
        signInMessage:
            'Milestone observations are private to your caregiver account.',
        signInIcon: Icons.flag_outlined,
      ),
      _buildAuthGatedTab(
        isAuthenticated: isAuthenticated,
        activeChild: activeChild,
        noChildView: noChildView,
        authenticatedChild: const JournalScreen(),
        signInTitle: 'Sign in for private journal',
        signInMessage:
            'Your caregiver notes are private and encrypted in your account.',
        signInIcon: Icons.book_outlined,
      ),
      _buildAuthGatedTab(
        isAuthenticated: isAuthenticated,
        activeChild: activeChild,
        noChildView: noChildView,
        authenticatedChild: WeeklySummaryScreen(
          onFindIdea: () => _selectDestination(1),
        ),
        signInTitle: 'Sign in for weekly summary',
        signInMessage: 'Weekly play progress is available when signed in.',
        signInIcon: Icons.insights_outlined,
      ),
    ];

    Future<void> onChildChipTap() async {
      if (!isAuthenticated) {
        await Navigator.pushNamed(
          context,
          AppRoutes.signIn,
          arguments: 'Please sign in to select or manage child profiles.',
        );
      } else {
        await Navigator.pushNamed(context, AppRoutes.children);
        if (mounted) {
          await _refreshChildren(force: true);
        }
      }
    }

    // IndexedStack keeps all five tab subtrees mounted so scroll position and
    // filter inputs persist when switching tabs.
    final tabStack = IndexedStack(index: _currentIndex, children: screens);
    final compactContent = ResponsiveContentBox(child: tabStack);
    final wideContent = ResponsiveContentBox(
      alignment: Alignment.topCenter,
      maxWidth: AppSizes.wideContentMaxWidth,
      child: tabStack,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final windowSize = AppWindowSize.fromWidth(constraints.maxWidth);
        final isWide = windowSize == AppWindowSize.expanded;
        final isExtendedRail =
            constraints.maxWidth >= AppSizes.extendedRailBreakpoint;

        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
                  title: compactHeader
                      ? IconButton(
                          tooltip: 'LittleSteps home',
                          onPressed: () => _selectDestination(0),
                          icon: const GrowthSymbol(size: 26),
                        )
                      : BrandLogo(onTap: () => _selectDestination(0)),
                  actions: [
                    if (activeChild != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compactHeader ? 148 : 220,
                        ),
                        child: ChildChip(
                          activeChild: activeChild,
                          compact: compactHeader,
                          onTap: onChildChipTap,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.account_circle_outlined,
                        size: 26,
                        color: AppColors.forest,
                      ),
                      tooltip: 'Account',
                      onPressed: () => _showAccountMenu(sessionState),
                    ),
                    const SizedBox(width: AppSpacing.space4),
                  ],
                ),
          body: isWide
              ? Row(
                  children: [
                    ShellNavigationSidebar(
                      destinations: _destinations,
                      selectedIndex: _currentIndex,
                      isExtended: isExtendedRail,
                      onDestinationSelected: _selectDestination,
                      onHomeTap: () => _selectDestination(0),
                      onAccountTap: () => _showAccountMenu(sessionState),
                      activeChild: activeChild,
                      onChildTap: onChildChipTap,
                      accountLabel: formattedCaregiver,
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space32,
                          vertical: AppSpacing.space16,
                        ),
                        child: wideContent,
                      ),
                    ),
                  ],
                )
              : compactContent,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: _destinations
                      .map(
                        (d) => NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Future<void> _handleSignOut(AuthSessionState? sessionState) async {
    if (sessionState != null) {
      await sessionState.signOut();
    }
    widget.onSignOut?.call();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.signIn,
        (route) => false,
      );
    }
  }

  void _handleChildDeleted(AuthSessionState? sessionState, String childId) {
    final remaining = _children.where((c) => c.id != childId).toList();
    setState(() {
      _children = remaining;
    });
    if (sessionState != null && sessionState.activeChild?.id == childId) {
      sessionState.setActiveChild(
        remaining.isNotEmpty ? remaining.first : null,
      );
    }
    widget.onChildDeleted?.call(childId);
  }

  Future<void> _showAccountMenu(AuthSessionState? sessionState) async {
    final effectiveEmail = sessionState?.currentUser?.email ?? widget.email;
    final effectiveChildren = _children.isNotEmpty
        ? _children
        : (sessionState?.activeChild != null
              ? <Child>[sessionState!.activeChild!]
              : widget.children);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;
    final resolvedApiClient = isAuthenticated
        ? AuthScope.apiClientOf(context)
        : null;
    final effectiveAccountService =
        widget.accountService ??
        (resolvedApiClient != null
            ? AccountService(apiClient: resolvedApiClient)
            : null);
    final effectiveChildrenService =
        widget.childrenService ??
        (resolvedApiClient != null
            ? ChildrenService(apiClient: resolvedApiClient)
            : null);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => AccountMenuSheet(
        email: effectiveEmail,
        children: effectiveChildren,
        activeChildId: sessionState?.activeChild?.id ?? widget.activeChildId,
        onChildSelected: (child) {
          if (sessionState != null) {
            sessionState.setActiveChild(child);
          }
          widget.onChildSelected?.call(child);
        },
        onSignOut: () async {
          // Close the modal bottom sheet before clearing session routes.
          Navigator.pop(sheetContext);
          await _handleSignOut(sessionState);
        },
        onOpenSettings: () {
          // Close the modal bottom sheet first so it is not still open on back.
          Navigator.pop(sheetContext);
          Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    email: effectiveEmail,
                    children: effectiveChildren,
                    accountService: effectiveAccountService,
                    childrenService: effectiveChildrenService,
                    onSignOut: isAuthenticated || widget.onSignOut != null
                        ? () => _handleSignOut(sessionState)
                        : null,
                    onAccountDeleted:
                        widget.onAccountDeleted ??
                        (isAuthenticated
                            ? () => _handleSignOut(sessionState)
                            : null),
                    onChildDeleted: (childId) =>
                        _handleChildDeleted(sessionState, childId),
                  ),
                ),
              )
              .then((_) {
                if (mounted && isAuthenticated) {
                  _refreshChildren(force: true);
                }
              });
        },
      ),
    );
  }
}
