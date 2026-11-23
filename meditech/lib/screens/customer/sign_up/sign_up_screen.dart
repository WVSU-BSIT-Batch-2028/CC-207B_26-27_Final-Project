import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import 'account_created_screen.dart';
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
  String? _mobileError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _mobile,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller.addListener(_onFieldsChanged);
    }
  }

  void _onFieldsChanged() {
    setState(() {
      if (_password.text.isNotEmpty &&
          _confirmPassword.text.isNotEmpty &&
          _password.text != _confirmPassword.text) {
        _confirmPasswordError = 'Passwords do not match.';
      } else if (_password.text == _confirmPassword.text) {
        _confirmPasswordError = null;
      }
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _mobile,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller
        ..removeListener(_onFieldsChanged)
        ..dispose();
    }
    super.dispose();
  }

  bool get _canSubmit {
    if (_busy) return false;
    if (!_agreed) return false;
    if (_birthdate == null) return false;
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      return false;
    }
    return _password.text == _confirmPassword.text;
  }

  String? get _submitHint {
    if (_busy) return null;
    if (!_agreed) {
      return 'Check the box to agree to the privacy notice.';
    }
    if (_birthdate == null) {
      return 'Select your birthdate to continue.';
    }
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      return 'Fill in all required fields.';
    }
    if (_password.text != _confirmPassword.text) {
      return 'Passwords must match before you can create an account.';
    }
    return null;
  }

  bool _isAlreadyRegisteredMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already') ||
        lower.contains('email address is already') ||
        lower.contains('duplicate key') ||
        lower.contains('unique constraint') ||
        lower.contains('accounts_pkey') ||
        lower.contains('user already registered');
  }

  bool _isMobileTakenMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('mobile number is already used');
  }

  bool _isMobileFormatMessage(String message) {
    return message.toLowerCase().contains('enter a mobile number like');
  }

  bool _isBirthdateMessage(String message) {
    return message.toLowerCase().contains('birthdate cannot be in the future');
  }

  bool _isEmailConfirmationMessage(String message) {
    return message.toLowerCase().contains('confirm your email');
  }

  bool _isRateLimitMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('too many sign-up') ||
        lower.contains('rate limit') ||
        lower.contains('too many attempts');
  }

  Future<void> _showEmailConfirmationDialog(String email) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your email'),
        content: const Text(
          'Open the link in your Gmail inbox (check spam). After confirming, '
          'sign in with the same email and password to finish your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(authServiceProvider)
                    .resendSignUpConfirmation(email);
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Confirmation email sent again.'),
                  ),
                );
              } on AppFailure catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            },
            child: const Text('Resend email'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sign-in');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRateLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Please wait'),
        content: const Text(
          'Our server is temporarily limiting new sign-ups from this device. '
          'Wait about 5 minutes and try again.\n\n'
          'If you already submitted the form, your account may exist—try signing in first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sign-in');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  void _applyUnhandledSignUpError(String message) {
    final lower = message.toLowerCase();
    setState(() {
      _offline = message == 'Could not reach Supabase.';
      if (_offline) {
        _formError = null;
        return;
      }
      if (lower.contains('password')) {
        _passwordError = message;
        _formError = null;
        return;
      }
      if (lower.contains('email') && !lower.contains('confirm your email')) {
        _emailError = message;
        _formError = null;
        return;
      }
      if (lower.contains('mobile')) {
        _mobileError = message;
        _formError = null;
        return;
      }
      _formError = message.isNotEmpty
          ? message
          : 'Could not create your account. Try again in a few minutes.';
    });
  }

  Future<void> _showAlreadyRegisteredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account already exists'),
        content: const Text(
          'An account is already registered with this email. Sign in instead, or use a different email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sign-in');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  // Save the account only when the form is complete and the passwords match
  Future<void> _signUp() async {
    if (!_canSubmit) return;

    setState(() {
      _formError = null;
      _mobileError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    if (_password.text != _confirmPassword.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match.';
      });
      return;
    }

    final cleanMobile = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(cleanMobile)) {
      setState(() {
        _mobileError =
            'Use a Philippine mobile number like 09171234567 (11 digits, starting with 09).';
      });
      return;
    }

    if (_password.text.length < 6) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters.';
      });
      return;
    }

    final email = _email.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() {
        _emailError = 'Enter a valid email address.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _offline = false;
    });

    try {
      await ref.read(authServiceProvider).signUp(
            firstName: _firstName.text,
            middleName: _middleName.text,
            lastName: _lastName.text,
            mobile: _mobile.text,
            email: _email.text,
            birthdate: _birthdate!,
            password: _password.text,
          );
      await ref.read(sessionProvider.notifier).signOut();
      if (!mounted) return;
      await showAccountCreatedModal(context);
      if (mounted) context.go('/sign-in');
    } on AppFailure catch (error) {
      try {
        await ref.read(sessionProvider.notifier).signOut();
      } catch (_) {}

      if (_isEmailConfirmationMessage(error.message)) {
        setState(() {
          _offline = false;
          _formError = error.message;
        });
        if (mounted) {
          await _showEmailConfirmationDialog(_email.text.trim());
        }
        return;
      }

      if (_isMobileFormatMessage(error.message)) {
        setState(() {
          _offline = false;
          _mobileError = error.message;
        });
        return;
      }

      if (_isBirthdateMessage(error.message)) {
        setState(() {
          _offline = false;
          _formError = error.message;
        });
        return;
      }

      if (_isMobileTakenMessage(error.message)) {
        setState(() {
          _offline = false;
          _mobileError = 'This mobile number is already used. Try another number or sign in.';
        });
        return;
      }

      if (_isAlreadyRegisteredMessage(error.message)) {
        if (mounted) {
          await _showAlreadyRegisteredDialog();
        }
        setState(() {
          _offline = false;
          _emailError =
              'This email is already registered. Sign in or use another email.';
        });
        return;
      }

      if (_isRateLimitMessage(error.message)) {
        setState(() {
          _offline = false;
          _formError = error.message;
        });
        if (mounted) {
          await _showRateLimitDialog();
        }
        return;
      }

      _applyUnhandledSignUpError(error.message);
    } on Exception catch (error) {
      try {
        await ref.read(sessionProvider.notifier).signOut();
      } catch (_) {}
      _applyUnhandledSignUpError(error.toString());
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
                if (_formError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _formError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 14),
                  ),
                ],
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
                  errorText: _mobileError,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email address',
                  controller: _email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Birthdate *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: _pickBirthdate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _birthdate == null
                        ? AppColors.textMuted
                        : AppColors.text,
                    side: BorderSide(
                      color: _birthdate == null ? AppColors.border : AppColors.primary,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(birthdateLabel),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Password',
                  controller: _password,
                  errorText: _passwordError,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Confirm password',
                  controller: _confirmPassword,
                  errorText: _confirmPasswordError,
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (value) => setState(() => _agreed = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'I agree to the ',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: const Text(
                          'Privacy Notice',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(
                        ' and the processing of my health data (Data Privacy Act of 2012).',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (_submitHint != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _submitHint!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _canSubmit ? _signUp : null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
                  ),
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