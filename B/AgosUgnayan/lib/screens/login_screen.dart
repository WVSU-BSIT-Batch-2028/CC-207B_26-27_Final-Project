// Login form: email and password, validated before we call Firebase.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_exception.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/loading_button.dart';
import '../widgets/responsive_body.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// Lets an existing user log in, or go to Register.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    // Stop here if any field shows an error.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().logIn(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome back', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 4),
        const Text(
          'Log in to see prices, buyers and your messages.',
          style: AppTextStyles.lead,
        ),
        const SizedBox(height: AppSizes.sectionGap),
        ..._fields(),
      ],
    );
    return Scaffold(
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Laptop: brand panel on the left, the form on the right.
            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  const Expanded(child: _BrandPanel()),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            // Phone and tablet: green banner on top, the form below.
            return ListView(
              children: [
                const _Hero(),
                ResponsiveBody(
                  maxWidth: 440,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.sectionGap,
                      AppSizes.pagePadding,
                      AppSizes.pagePadding,
                    ),
                    child: form,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The email and password fields, the Log in button and the Register link.
  List<Widget> _fields() {
    return [
      TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(labelText: 'Email'),
        keyboardType: TextInputType.emailAddress,
        validator: Validators.email,
      ),
      const SizedBox(height: AppSizes.fieldGap),
      TextFormField(
        controller: _passwordController,
        obscureText: _hidePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            tooltip: _hidePassword ? 'Show password' : 'Hide password',
            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
          ),
        ),
        validator: Validators.password,
        onFieldSubmitted: (_) => _logIn(),
      ),
      const SizedBox(height: AppSizes.sectionGap),
      LoadingButton(label: 'Sign In', isLoading: _isLoading, onPressed: _logIn),
      const SizedBox(height: AppSizes.small),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('New to AgosUgnayan?'),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: const Text('Create an account'),
          ),
        ],
      ),
    ];
  }
}

/// Green banner with the logo, the app name and the tagline (website .hero).
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveBody(
          maxWidth: 440,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              28,
              AppSizes.pagePadding,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(size: 52),
                const SizedBox(height: 12),
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.logo.copyWith(fontSize: 40, height: 0.9),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppStrings.tagline,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The left half of the laptop login: logo, name, tagline and the three
/// things the app helps with, so new visitors know what it is for.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.all(48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(size: 64),
              const SizedBox(height: 16),
              Text(
                AppStrings.appName,
                style: AppTextStyles.logo.copyWith(fontSize: 52, height: 0.9),
              ),
              const SizedBox(height: 12),
              const Text(
                AppStrings.tagline,
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 36),
              const _Point(
                icon: Icons.trending_up,
                title: 'Real PSA prices',
                text:
                    'Monthly farmgate prices for Iloilo, with the month shown.',
              ),
              const _Point(
                icon: Icons.storefront_outlined,
                title: 'Sell to local buyers',
                text: 'Farmers list crops; buyers post what they need.',
              ),
              const _Point(
                icon: Icons.chat_bubble_outline,
                title: 'Talk directly',
                text: 'Message each other and agree on a fair price.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line on the brand panel: an icon in a circle, a title and a sentence.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.onPrimaryMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
