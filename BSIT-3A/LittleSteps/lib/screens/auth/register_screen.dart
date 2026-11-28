import 'package:flutter/material.dart';

import '../../config/external_links.dart';
import '../../routing/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/accessibility.dart';
import '../../utils/url_helper.dart';
import '../../widgets/auth_scope.dart';
import 'widgets/auth_widgets.dart';

/// Caregiver registration screen.
///
/// Displays the privacy notice before account creation, uses
/// [AuthResponsiveLayout] for consistent responsive presentation, and
/// announces validation and submission status changes to assistive
/// technologies.
class RegisterScreen extends StatefulWidget {
  /// Creates a [RegisterScreen].
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const List<String> _desktopHighlights = [
    'Use only a child nickname and age band.',
    'Private notes stay with your account.',
    'Offline reading for saved daily plans.',
  ];

  static const List<MapEntry<String, String>> _privacyPoints = [
    MapEntry(
      'What we collect',
      'A child nickname, birth month and year, activity records and your notes.',
    ),
    MapEntry(
      'Why',
      'To suggest age-suitable activities and keep your own record.',
    ),
    MapEntry(
      'Who sees it',
      'Only you. Notes never go to external AI, analytics, or error logs.',
    ),
    MapEntry(
      'Your rights',
      'You can view and modify what you entered anytime in the app.',
    ),
    MapEntry(
      'If something goes wrong',
      'We aim to notify you and the National Privacy Commission within 72 hours.',
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _acceptedPrivacy = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _announce(String message) => announceForAccessibility(context, message);

  Future<void> _submit() async {
    if (!_acceptedPrivacy) {
      const msg =
          'Please read and accept the privacy notice before creating an account.';
      setState(() => _errorMessage = msg);
      _announce(msg);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final sessionState = AuthScope.of(context);

    try {
      await sessionState.createAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _announce('Account created successfully');
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _submitting = false;
      });
      _announce(e.message);
    } catch (_) {
      if (!mounted) return;
      const generic =
          'Something went wrong while creating your account. Please try again.';
      setState(() {
        _errorMessage = generic;
        _submitting = false;
      });
      _announce(generic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AuthResponsiveLayout(
        panelTitle: 'Create your account',
        panelSubtitle: "For parents and guardians who add their own child's details and keep everyday play notes.",
        panelHighlights: _desktopHighlights,
        compactMaxWidth: 460,
        wideFormMaxWidth: 460,
        card: AutofillGroup(
          child: Form(
            key: _formKey,
            child: AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create an account',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    "For parents and guardians who add their own child's details.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  if (_errorMessage != null) ...[
                    AuthMessageBanner(
                      message: _errorMessage!,
                      tone: AuthMessageTone.error,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                  ],
                  AuthEmailField(controller: _emailController),
                  const SizedBox(height: AppSpacing.space12),
                  AuthPasswordField(
                    controller: _passwordController,
                    showPassword: _showPassword,
                    autofillHint: AutofillHints.newPassword,
                    helperText: 'At least 8 characters',
                    minLength: 8,
                    onToggleVisibility: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    onSubmitted: _submit,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  AuthPrivacyNoticeCard(
                    points: _privacyPoints,
                    accepted: _acceptedPrivacy,
                    contactTitle: 'Thesis Titans',
                    contactDomain: 'github.com/Thesis-Titans',
                    onContactTap: () =>
                        openExternalUrl(context, AppLinks.githubOrg),
                    onChanged: (accepted) {
                      setState(() {
                        _acceptedPrivacy = accepted;
                        if (_acceptedPrivacy) _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  AuthSubmitButton(
                    label: 'Create account',
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        footer: AuthAccountFooter(
          prompt: 'Already have an account?',
          actionLabel: 'Sign in',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.signIn);
            }
          },
        ),
      ),
    );
  }
}
