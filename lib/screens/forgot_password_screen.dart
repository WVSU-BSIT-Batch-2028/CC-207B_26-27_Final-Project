import 'package:flutter/material.dart';
import '../foodwise_theme.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.sendPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If an account exists for that email, a reset link has been sent.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Forgot Password')),
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
                      decoration: const BoxDecoration(color: FoodWiseColors.lightOrange, shape: BoxShape.circle),
                      child: const Icon(Icons.lock_reset_rounded, color: FoodWiseColors.deepOrange, size: 46),
                    ),
                    const SizedBox(height: 28),
                    const Text('Reset your password', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    const SizedBox(height: 10),
                    const Text(
                      'Enter the email address linked to your FoodWise account. We\u2019ll send you instructions to reset your password.',
                      style: TextStyle(color: FoodWiseColors.muted, height: 1.6, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address', hintText: 'you@example.com', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) {
                        if (value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading || _sent ? null : _sendResetLink,
                      child: _loading
                          ? const SizedBox(height: 21, width: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_sent ? 'Reset Link Sent' : 'Send Reset Link'),
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Check your inbox and spam folder. Follow the link to continue the password reset process.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FoodWiseColors.muted, height: 1.5, fontSize: 12),
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
