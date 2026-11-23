import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/customer_notification_preferences.dart';
import '../../../providers/profile_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

final notificationPreferencesProvider =
    FutureProvider<CustomerNotificationPreferences>((ref) {
  return ref.watch(profileServiceProvider).loadNotificationPreferences();
});

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  CustomerNotificationPreferences? _draft;
  var _busy = false;
  String? _error;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileServiceProvider).saveNotificationPreferences(draft);
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(customerProfileOverviewProvider);
      if (!mounted) return;
      context.pop();
    } on AppFailure catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (loaded) {
          _draft ??= loaded;
          final draft = _draft!;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text(
                'Choose how we reach you about reservations and pickup updates.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                title: const Text('Push notifications'),
                subtitle: const Text('Alerts inside the app'),
                value: draft.pushEnabled,
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _draft = draft.copyWith(pushEnabled: value),
                        ),
              ),
              SwitchListTile(
                title: const Text('Email'),
                subtitle: const Text('Messages to your registered email'),
                value: draft.emailEnabled,
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _draft = draft.copyWith(emailEnabled: value),
                        ),
              ),
              SwitchListTile(
                title: const Text('SMS'),
                subtitle: const Text('Texts to your mobile number'),
                value: draft.smsEnabled,
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _draft = draft.copyWith(smsEnabled: value),
                        ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save preferences'),
              ),
            ],
          );
        },
      ),
    );
  }
}