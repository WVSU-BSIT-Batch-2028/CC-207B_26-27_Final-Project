import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/child.dart';
import '../../models/weather.dart';
import '../../routing/app_router.dart';
import '../../services/account_service.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';

/// Account, child profile, and data rights settings.
class SettingsScreen extends StatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({
    super.key,
    this.email,
    this.children = const [],
    this.accountService,
    this.childrenService,
    this.onSignOut,
    this.onAccountDeleted,
    this.onChildDeleted,
  });

  /// Signed-in caregiver email address, or `null` when unavailable.
  final String? email;

  /// Child profiles available for per-child deletion actions.
  final List<Child> children;

  /// Service used to export caregiver data and delete the account.
  final AccountService? accountService;

  /// Service used to delete individual child profiles.
  final ChildrenService? childrenService;

  /// Callback invoked when the caregiver signs out.
  final VoidCallback? onSignOut;

  /// Callback invoked after the caregiver account is deleted.
  final VoidCallback? onAccountDeleted;

  /// Callback invoked with the child ID after a child profile is deleted.
  final ValueChanged<String>? onChildDeleted;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  final Set<String> _deletingChildren = {};
  bool _isDeletingAccount = false;
  late final List<Child> _children = List.of(widget.children);
  bool _loadedRemoteChildren = false;
  WeatherLocation? _localWeatherLocation = WeatherLocation.iloiloCity;

  String? get _effectiveEmail =>
      widget.email ?? AuthScope.maybeOf(context)?.currentUser?.email;

  AccountService? get _effectiveAccountService {
    if (widget.accountService != null) return widget.accountService;
    final session = AuthScope.maybeOf(context);
    if (session != null && session.isAuthenticated) {
      return AccountService(apiClient: AuthScope.apiClientOf(context));
    }
    return null;
  }

  ChildrenService? get _effectiveChildrenService {
    if (widget.childrenService != null) return widget.childrenService;
    final session = AuthScope.maybeOf(context);
    if (session != null && session.isAuthenticated) {
      return ChildrenService(apiClient: AuthScope.apiClientOf(context));
    }
    return null;
  }

  VoidCallback? get _effectiveSignOut {
    if (widget.onSignOut != null) return widget.onSignOut;
    final session = AuthScope.maybeOf(context);
    if (session != null && session.isAuthenticated) {
      return () async {
        await session.signOut();
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.signIn, (_) => false);
        }
      };
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedRemoteChildren && _children.isEmpty) {
      final service = _effectiveChildrenService;
      if (service != null) {
        _loadedRemoteChildren = true;
        _loadChildren(service);
      }
    }
  }

  Future<void> _loadChildren(ChildrenService service) async {
    try {
      final fetched = await service.getChildren();
      if (!mounted) return;
      setState(() {
        _children
          ..clear()
          ..addAll(fetched);
      });
    } catch (_) {
      // Keep the current list when offline or unavailable.
    }
  }

  WeatherLocation? _currentWeatherLocation(BuildContext context) {
    final session = AuthScope.maybeOf(context);
    if (session != null) return session.weatherLocation;
    return _localWeatherLocation;
  }

  void _updateWeatherLocation(BuildContext context, String? cityName) {
    final selected = WeatherLocation.byName(cityName);
    final session = AuthScope.maybeOf(context);
    if (session != null) {
      session.setWeatherLocation(selected);
    } else {
      setState(() => _localWeatherLocation = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _effectiveEmail;
    final accountService = _effectiveAccountService;
    final childrenService = _effectiveChildrenService;
    final signOutAction = _effectiveSignOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveContentBox(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            _SettingsGroup(
              title: 'Account',
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(email ?? 'Account details'),
                  subtitle: Text(
                    email == null
                        ? 'Sign in to view caregiver details.'
                        : 'Signed-in caregiver',
                  ),
                ),
                _SettingsAction(
                  icon: Icons.logout,
                  title: 'Sign out',
                  subtitle: 'Sign out when you are done on a shared phone.',
                  onTap: signOutAction ?? _showSignInUnavailable,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            _SettingsGroup(
              title: 'Children',
              children: [
                if (_children.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.child_care_outlined),
                    title: Text(
                      email == null
                          ? 'Sign in to view child profiles'
                          : 'No children added yet',
                    ),
                  )
                else
                  for (final child in _children)
                    _SettingsAction(
                      icon: Icons.delete_outline,
                      title: 'Delete ${child.nickname}’s records',
                      subtitle: 'Remove this child and their saved records.',
                      isLoading: _deletingChildren.contains(child.id),
                      isDestructive: true,
                      onTap: childrenService == null
                          ? _showSignInUnavailable
                          : () => _confirmDeleteChild(child),
                    ),
                _SettingsAction(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Add a child',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.childrenAdd),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            _SettingsGroup(
              title: 'Your data',
              children: [
                _SettingsAction(
                  icon: Icons.download_outlined,
                  title: 'Download my data',
                  subtitle: 'Get a JSON copy of your account and child data, including journal notes.',
                  isLoading: _isExporting,
                  onTap: _downloadData,
                ),
                _SettingsAction(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete my account',
                  subtitle: 'Permanently remove your account and its records.',
                  isLoading: _isDeletingAccount,
                  isDestructive: true,
                  onTap: accountService == null
                      ? _showSignInUnavailable
                      : _confirmDeleteAccount,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            _SettingsGroup(
              title: 'Weather for activity ideas',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        key: const ValueKey('settings_weather_city_dropdown'),
                        isExpanded: true,
                        initialValue:
                            _currentWeatherLocation(context)?.name ?? '',
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.wb_sunny_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Off (no weather hints)'),
                          ),
                          for (final city in WeatherLocation.philippinesCities)
                            DropdownMenuItem<String>(
                              value: city.name,
                              child: Text(city.name),
                            ),
                        ],
                        onChanged: (value) =>
                            _updateWeatherLocation(context, value),
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        'Weather data by Open-Meteo.com. No location data is stored beyond your chosen city.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (accountService == null || childrenService == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.space12),
                child: Text(
                  'Account actions will be available after sign-in is connected.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadData() async {
    final service = _effectiveAccountService;
    if (service == null) {
      _showSignInUnavailable();
      return;
    }

    setState(() => _isExporting = true);
    try {
      final json = const JsonEncoder.withIndent('  ')
          .convert(await service.exportData());
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: 'littlesteps-data.json',
            ),
          ],
          fileNameOverrides: const ['littlesteps-data.json'],
          title: 'Your LittleSteps data',
          downloadFallbackEnabled: true,
        ),
      );
    } catch (_) {
      _showMessage('We could not prepare your data. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmDeleteChild(Child child) async {
    final confirmed = await _confirmDeletion(
      title: 'Delete ${child.nickname}’s records?',
      message:
          'This permanently deletes ${child.nickname}’s profile, plans, '
          'observations, journal entries and weekly summaries.',
      confirmLabel: 'Delete records',
    );
    if (!confirmed || !mounted) return;

    final service = _effectiveChildrenService;
    if (service == null) {
      _showSignInUnavailable();
      return;
    }

    setState(() => _deletingChildren.add(child.id));
    try {
      await service.deleteChild(child.id);
      if (mounted) {
        setState(() => _children.removeWhere((item) => item.id == child.id));
        final session = AuthScope.maybeOf(context);
        if (session != null && session.activeChild?.id == child.id) {
          session.setActiveChild(_children.isNotEmpty ? _children.first : null);
        }
      }
      widget.onChildDeleted?.call(child.id);
      _showMessage('${child.nickname}’s records were deleted.');
    } catch (_) {
      _showMessage('We could not delete these records. Try again.');
    } finally {
      if (mounted) setState(() => _deletingChildren.remove(child.id));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await _confirmDeletion(
      title: 'Delete your account?',
      message:
          'This permanently deletes your account, all child profiles, plans, '
          'observations, journal entries and weekly summaries.',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !mounted) return;

    final service = _effectiveAccountService;
    if (service == null) {
      _showSignInUnavailable();
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      await service.deleteAccount();
      if (widget.onAccountDeleted != null) {
        widget.onAccountDeleted!();
      } else if (mounted) {
        final session = AuthScope.maybeOf(context);
        if (session != null) {
          await session.signOut();
        }
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.signIn, (_) => false);
        }
      }
    } catch (_) {
      _showMessage('We could not delete your account. Try again.');
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<bool> _confirmDeletion({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSignInUnavailable() {
    _showMessage('Sign in to use this account action.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.textError : null;
    return ListTile(
      minTileHeight: AppSizes.touchTarget,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: isLoading
          ? const SizedBox.square(
              dimension: AppSpacing.space24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isLoading ? null : onTap,
    );
  }
}
