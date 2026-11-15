import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// Ask for a code, then save a new password
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _busy = false;
  var _codeSent = false;
  var _saved = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Send the code to the email on the account
  Future<void> _send() async {
    if (_identifier.text.trim().isEmpty) {
      setState(() {
        _offline = false;
        _error = 'Enter your email or mobile number.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordReset(identifier: _identifier.text);
      setState(() => _codeSent = true);
    } on AppFailure catch (error) {
      setState(() {
        _offline = error.message == 'Could not reach Supabase.';
        _error = _offline ? null : error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Save the new password only when the code is present and the two boxes match
  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _password.text.isEmpty || _confirmPassword.text.isEmpty) {
      setState(() {
        _offline = false;
        _saved = false;
        _error = 'Enter the code and a new password.';
      });
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() {
        _offline = false;
        _saved = false;
        _error = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
      _saved = false;
    });

    try {
      await ref.read(authServiceProvider).resetPassword(
            identifier: _identifier.text,
            code: _code.text,
            newPassword: _password.text,
          );
      setState(() => _saved = true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppTextField(
                  label: 'Email or mobile',
                  controller: _identifier,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_codeSent)
                  FilledButton(
                    onPressed: _busy ? null : _send,
                    child: _busy
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send code'),
                  ),
                if (_codeSent && !_saved) ...[
                  const Text('If an account exists, we sent a code to its email.'),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Code',
                    controller: _code,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(label: 'New password', controller: _password),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    label: 'Confirm password',
                    controller: _confirmPassword,
                    errorText: _error,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save password'),
                  ),
                ],
                if (_saved) ...[
                  const Text('Password saved. Sign in with your new password.'),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('Sign in'),
                  ),
                ],
                if (_error != null && !_codeSent) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}