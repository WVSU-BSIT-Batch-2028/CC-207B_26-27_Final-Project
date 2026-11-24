import 'package:flutter/material.dart';

import '../../foodwise_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/feedback_banner.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../student_home_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _obscurePassword = true;
  FeedbackData? _feedback;
  String? _verificationEmail;

  bool get _busy => _loading || _resending;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearFeedback() {
    if (_feedback != null || _verificationEmail != null) {
      setState(() {
        _feedback = null;
        _verificationEmail = null;
      });
    }
  }

  Future<void> _login() async {
    if (_busy) {
      return;
    }
    _clearFeedback();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    setState(() => _loading = true);
    var signedIn = false;
    try {
      final response = await AuthService.loginStudent(
        email: email,
        password: _passwordController.text,
      );
      signedIn = response.session != null;
      if (!signedIn) {
        if (!mounted) {
          return;
        }
        setState(
          () => _feedback = AppFeedback.failure(
            'Unable to sign in',
            'Your session could not start. Please try again.',
          ),
        );
        return;
      }
      final profile = await AuthService.getProfile();
      if (profile == null || profile['role'] != 'student') {
        await AuthService.logout();
        signedIn = false;
        if (!mounted) {
          return;
        }
        setState(
          () => _feedback = profile == null
              ? AppFeedback.failure(
                  'Student profile unavailable',
                  'Your student profile could not be found. Contact support for assistance.',
                )
              : AppFeedback.warning(
                  'Student account required',
                  'This account is not registered as a student. Sign in with your student account.',
                ),
        );
        return;
      }
      if (!mounted) {
        await AuthService.logout();
        return;
      }
      _passwordController.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        (_) => false,
      );
    } catch (error) {
      // Do not leave a session active when student-profile validation fails.
      if (signedIn) {
        try {
          await AuthService.logout();
        } catch (_) {
          if (!mounted) {
            return;
          }
          setState(
            () => _feedback = AppFeedback.failure(
              'Unable to complete sign-in',
              'Your student account could not be verified and the session could not be closed. Please try again or contact support.',
            ),
          );
          return;
        }
      }
      if (!mounted) {
        return;
      }
      final feedback = AppFeedback.fromError(
        error,
        title: 'Unable to sign in',
        fallback: 'Sign-in could not be completed. Please try again.',
      );
      setState(() {
        _feedback = feedback;
        _verificationEmail = feedback.actionLabel == 'Resend verification email'
            ? email
            : null;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    final email = _verificationEmail;
    if (_busy || email == null || email != _emailController.text.trim()) {
      return;
    }
    setState(() => _resending = true);
    try {
      await AuthService.resendVerificationEmail(email);
      if (!mounted) {
        return;
      }
      setState(() {
        _verificationEmail = null;
        _feedback = AppFeedback.success(
          'Verification requested',
          'Check your inbox or spam folder for the confirmation link. Once verified, sign in again.',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final feedback = AppFeedback.fromError(
        error,
        title: 'Unable to resend email',
        fallback:
            'The verification email could not be requested. Please try again.',
      );
      setState(
        () => _feedback = FeedbackData(
          title: feedback.title,
          message: feedback.message,
          type: feedback.type,
          actionLabel: 'Resend verification email',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _busy
                ? null
                : () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (_) => false,
                  ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 8, 25, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _brandMark(),
                      const SizedBox(height: 27),
                      const Text(
                        'Welcome back!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to find your next favorite meal.',
                        style: TextStyle(
                          color: FoodWiseColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 27),
                      _formCard(),
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'New to FoodWise? ',
                            style: TextStyle(color: FoodWiseColors.muted),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandMark() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: FoodWiseColors.deepOrange,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
      ),
      const SizedBox(width: 11),
      const Text(
        'FoodWise',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    ],
  );

  Widget _formCard() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: FoodWiseColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: FoodWiseColors.border),
      boxShadow: [
        BoxShadow(
          color: FoodWiseColors.deepOrange.withValues(alpha: .06),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign In',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => _clearFeedback(),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())
                ? 'Enter a valid email address'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            enabled: !_busy,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _login(),
            onChanged: (_) {
              // Keep email-verification feedback while correcting a password.
              if (_verificationEmail == null) {
                _clearFeedback();
              }
            },
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: _busy
                    ? null
                    : () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: FoodWiseColors.sage,
                ),
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Please enter your password'
                : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    ),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 8),
          if (_feedback != null) ...[
            FeedbackBanner(
              feedback: _feedback!,
              onAction: _verificationEmail != null && !_loading
                  ? _resendVerification
                  : null,
              actionLoading: _resending,
              onDismiss: _busy ? null : _clearFeedback,
            ),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _busy ? null : _login,
            child: _loading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Signing in…'),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Sign In'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
