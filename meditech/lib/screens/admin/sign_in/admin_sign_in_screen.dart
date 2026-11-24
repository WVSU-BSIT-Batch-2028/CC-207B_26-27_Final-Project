import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../shared/notification_bell.dart';

// An administrator signs in with a username
class AdminSignInScreen extends ConsumerStatefulWidget {
  const AdminSignInScreen({super.key});

  @override
  ConsumerState<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends ConsumerState<AdminSignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  // Send the username and password to the admin sign-in
  Future<void> _signIn() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _offline = false;
        _error = 'Enter your username and password.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      await ref.read(sessionProvider.notifier).signIn(
            identifier: username,
            password: password,
            app: 'admin',
          );
    } on AppFailure catch (error) {
      setState(() {
        _offline = error.message == 'Could not reach Supabase.';
        _error = _offline ? null : error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(sessionProvider);
    final signedIn = account != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const _MediTechMark(),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Admin sign in',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Use your administrator username and password.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (signedIn) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Signed in as ${account.role ?? account.accountType}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const NotificationBell(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: () => context.push('/audit'),
                          child: const Text('Audit records'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(sessionProvider.notifier).signOut();
                            if (context.mounted) context.go('/');
                          },
                          child: const Text('Switch user'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ] else ...[
                        AppTextField(
                          label: 'Username',
                          controller: _username,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppPasswordField(
                          label: 'Password',
                          controller: _password,
                          errorText: _error,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Sessions sign out after 10 minutes of inactivity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediTechMark extends StatelessWidget {
  const _MediTechMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/images/Meditech Logo.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'MediTech',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}