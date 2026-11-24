import 'package:flutter/material.dart';

import '../../foodwise_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/feedback_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _loading = false;
  bool _sent = false;
  FeedbackData? _feedback;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_loading || _sent) {
      return;
    }
    setState(() => _feedback = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await AuthService.sendPasswordReset(_emailController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _sent = true;
        _feedback = AppFeedback.success(
          'Password reset requested',
          'If an account exists for this email, you will receive a password reset link. Check your inbox and spam folder, then follow the instructions.',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _feedback = AppFeedback.fromError(
          error,
          title: 'Unable to request password reset',
          fallback: 'The reset link could not be requested. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 86,
                      width: 86,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: FoodWiseColors.lightOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: FoodWiseColors.deepOrange,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Reset your password',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enter the email address linked to your FoodWise account. We’ll send you instructions to reset your password.',
                      style: TextStyle(
                        color: FoodWiseColors.muted,
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _sendResetLink(),
                      onChanged: (_) {
                        if (_feedback != null || _sent) {
                          setState(() {
                            _feedback = null;
                            _sent = false;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_feedback != null) ...[
                      FeedbackBanner(feedback: _feedback!),
                      const SizedBox(height: 14),
                    ],
                    FilledButton(
                      onPressed: _loading || _sent ? null : _sendResetLink,
                      child: _loading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Sending request…'),
                              ],
                            )
                          : Text(
                              _sent
                                  ? 'Reset Link Requested'
                                  : 'Send Reset Link',
                            ),
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to Sign In'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
