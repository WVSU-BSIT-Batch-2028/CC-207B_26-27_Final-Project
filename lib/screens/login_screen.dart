import 'package:flutter/material.dart';
import '../foodwise_theme.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.loginStudent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final profile = await AuthService.getProfile();
      if (profile == null) {
        await AuthService.logout();
        throw Exception('Student profile not found.');
      }
      if (profile['role'] != 'student') {
        await AuthService.logout();
        throw Exception('This account is not registered as a student.');
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: FoodWiseColors.deepOrange,
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pushAndRemoveUntil(
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
                    const Text('Welcome back!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                    const SizedBox(height: 8),
                    const Text('Sign in to find your next favorite meal.', style: TextStyle(color: FoodWiseColors.muted, fontSize: 14)),
                    const SizedBox(height: 27),
                    _formCard(),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New to FoodWise? ', style: TextStyle(color: FoodWiseColors.muted)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
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
        child: const Icon(
          Icons.restaurant_menu_rounded,
          color: Colors.white,
        ),
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
          boxShadow: [BoxShadow(color: FoodWiseColors.deepOrange.withValues(alpha: .06), blurRadius: 25, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sign In', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address', hintText: 'Enter your email', prefixIcon: Icon(Icons.mail_outline)),
              validator: (value) => value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? 'Enter a valid email address' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(height: 21, width: 21, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Sign In'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 19)]),
            ),
          ],
        ),
      );
}
