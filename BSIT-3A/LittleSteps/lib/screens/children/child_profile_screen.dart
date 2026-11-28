import 'package:flutter/material.dart';

import '../../models/child.dart';
import '../../routing/app_router.dart';
import '../../services/api_client.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/no_children_view.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/state_views.dart';
import 'add_child_screen.dart';
import 'widgets/child_widgets.dart';

/// Lists the caregiver's child profiles and lets them switch or edit profiles.
///
/// Shows a loading state while fetching profiles, an offline notice or retryable
/// error view on failure, and [NoChildrenView] when no profiles exist yet.
class ChildProfileScreen extends StatefulWidget {
  /// Creates a [ChildProfileScreen].
  const ChildProfileScreen({
    super.key,
    this.children,
    this.childrenService,
    this.onChildSelected,
  });

  /// Optional list of child profiles to display instead of loading from the API.
  final List<Child>? children;

  /// Optional service override used to load profiles.
  ///
  /// When `null`, this screen builds a [ChildrenService] from [AuthScope].
  final ChildrenService? childrenService;

  /// Callback invoked after the caregiver switches the active child.
  final ValueChanged<Child>? onChildSelected;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  Future<List<Child>>? _childrenFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_childrenFuture == null) {
      _load();
    }
  }

  void _load() {
    setState(() {
      _childrenFuture = _fetchChildren();
    });
  }

  Future<List<Child>> _fetchChildren() async {
    final given = widget.children;
    if (given != null) {
      return given;
    }
    final session = AuthScope.maybeOf(context);
    final service =
        widget.childrenService ??
        ChildrenService(apiClient: AuthScope.apiClientOf(context));

    final children = await service.getChildren();
    if (session != null && session.activeChild == null && children.isNotEmpty) {
      session.setActiveChild(children.first);
    }
    return children;
  }

  Future<void> _openAddChild() async {
    await Navigator.pushNamed(context, AppRoutes.childrenAdd);
    if (!mounted) return;
    _load();
  }

  Future<void> _openEditChild(Child child) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AddChildScreen(child: child)),
    );
    if (!mounted) return;
    _load();
  }

  void _select(Child child) {
    AuthScope.maybeOf(context)?.setActiveChild(child);
    widget.onChildSelected?.call(child);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Switched to ${child.nickname}'),
          duration: AppMotion.snackbarShort,
        ),
      );
  }

  String? _caregiverName() {
    final email = AuthScope.maybeOf(context)?.currentUser?.email;
    if (email == null || !email.contains('@')) return null;
    final name = email.split('@').first;
    if (name.isEmpty) return null;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(title: const Text('Children')),
      body: FutureBuilder<List<Child>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading children...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is NoConnectionApiException || error is! ApiException) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  child: ChildOfflineNotice(onRetry: _load),
                ),
              );
            }
            return ErrorView(
              message: "Couldn't load children. Please try again.",
              onRetry: _load,
            );
          }

          final children = snapshot.data ?? const <Child>[];
          if (children.isEmpty) {
            return NoChildrenView(
              caregiverName: _caregiverName(),
              onAddChild: _openAddChild,
            );
          }
          return _buildChildrenList(context, children);
        },
      ),
    );
  }

  Widget _buildChildrenList(BuildContext context, List<Child> children) {
    final theme = Theme.of(context);
    final activeChildId = AuthScope.maybeOf(context)?.activeChild?.id;
    final profileWord = children.length == 1 ? 'profile' : 'profiles';

    return ResponsiveContentBox(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          Text(
            'Manage your private family space.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          Text(
            'Your children (${children.length} $profileWord)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          for (final child in children)
            ChildProfileCard(
              child: child,
              isCurrent: child.id == activeChildId,
              onSelect: () => _select(child),
              onEdit: () => _openEditChild(child),
            ),
          const SizedBox(height: AppSpacing.space12),
          OutlinedButton.icon(
            onPressed: _openAddChild,
            icon: const Icon(Icons.add),
            label: const Text('Add a child'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.touchTarget),
            ),
          ),
          const SizedBox(height: AppSpacing.space24),
          const ChildPrivacyHintCard(),
        ],
      ),
    );
  }
}
