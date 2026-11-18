import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// A new customer fills in their name, mobile, email, and password
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  DateTime? _birthdate;
  var _agreed = false;
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Save the account only when the form is complete and the passwords match
  Future<void> _signUp() async {
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _birthdate == null) {
      setState(() {
        _offline = false;
        _error = 'Fill in every field. Middle name can be left blank.';
      });
      return;
    }
    if (!_agreed) {
      setState(() {
        _offline = false;
        _error = 'Agree to the privacy notice before creating an account.';
      });
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() {
        _offline = false;
        _error = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      final account = await ref.read(authServiceProvider).signUp(
            firstName: _firstName.text,
            middleName: _middleName.text,
            lastName: _lastName.text,
            mobile: _mobile.text,
            email: _email.text,
            birthdate: _birthdate!,
            password: _password.text,
          );
      ref.read(sessionProvider.notifier).setSignedIn(account);
      if (mounted) context.go('/account-created');
    } on AppFailure catch (error) {
      setState(() {
        _offline = error.message == 'Could not reach Supabase.';
        _error = _offline ? null : error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBirthdate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final birthdateLabel = _birthdate == null
        ? 'mm/dd/yyyy'
        : '${_birthdate!.month.toString().padLeft(2, '0')}/${_birthdate!.day.toString().padLeft(2, '0')}/${_birthdate!.year}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Create your account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Keep your prescriptions and medicine searches in one secure place.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'First name',
                  controller: _firstName,
                  hint: 'e.g. Juan',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Middle name',
                  controller: _middleName,
                  hint: 'Optional',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Last name',
                  controller: _lastName,
                  hint: 'e.g. Dela Cruz',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Mobile number',
                  controller: _mobile,
                  hint: '09XXXXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email address',
                  controller: _email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Birthdate',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: _pickBirthdate,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(birthdateLabel),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(label: 'Password', controller: _password),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Confirm password',
                  controller: _confirmPassword,
                  errorText: _error,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (value) => setState(() => _agreed = value ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'I agree to the Privacy Notice and the processing of my health data (Data Privacy Act of 2012).',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _signUp,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.push('/sign-in'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
