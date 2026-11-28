import 'package:flutter/material.dart';

import '../../routing/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/accessibility.dart';
import '../../widgets/auth_scope.dart';
import 'widgets/auth_widgets.dart';

/// Screen that allows caregivers to sign in with their email and password.
///
/// Adapts between a zero-scroll compact layout on phones and a two-pane split
/// layout on wide tablet and desktop viewports while supporting screen readers
/// and 200% text scaling.
class SignInScreen extends StatefulWidget {
  /// Creates a [SignInScreen] with optional [notice] message.
  const SignInScreen({super.key, this.notice});

  /// Optional notice displayed above the form (e.g., from an expired session).
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const List<String> _desktopHighlights = [
    'Plan play and note what you can.',
    'Your journal stays private.',
    'Every activity shows where it comes from.',
  ];

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _announce(String message) => announceForAccessibility(context, message);

  Future<void> _submit([
    String? overrideEmail,
    String? overridePassword,
  ]) async {
    final email = overrideEmail ?? _emailController.text.trim();
    final password = overridePassword ?? _passwordController.text;

    if (overrideEmail == null && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final sessionState = AuthScope.of(context);
    final apiClient = AuthScope.apiClientOf(context);

    try {
      await sessionState.signIn(email: email, password: password);
      try {
        final childrenService = ChildrenService(apiClient: apiClient);
        final children = await childrenService.getChildren();
        if (children.isNotEmpty && sessionState.activeChild == null) {
          sessionState.setActiveChild(children.first);
        }
      } catch (_) {}
      if (!mounted) return;
      _announce('Signed in successfully');
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
          'Something went wrong while signing in. Please try again.';
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
    final sessionState = AuthScope.maybeOf(context);
    final activeNotice =
        widget.notice ??
        (sessionState?.unsavedDraft != null
            ? 'Please sign in again to continue. Your unsaved draft has been kept.'
            : null);

    return Scaffold(
      body: AuthResponsiveLayout(
        panelTitle: 'Welcome back',
        panelSubtitle: 'Plan short play ideas, notice small moments, and keep private notes for the children you care for.',
        panelHighlights: _desktopHighlights,
        wideFormMaxWidth: 420,
        card: AutofillGroup(
          child: Form(
            key: _formKey,
            child: AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign in',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Sign in to your caregiver account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  if (activeNotice != null) ...[
                    AuthMessageBanner(
                      message: activeNotice,
                      tone: AuthMessageTone.notice,
                    ),
                    const SizedBox(height: AppSpacing.space12),
                  ],
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
                    onToggleVisibility: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    onSubmitted: _submit,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password reset instructions will be sent to your registered email address.',
                            ),
                            duration: AppMotion.snackbarDefault,
                          ),
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  AuthSubmitButton(
                    label: 'Sign in',
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        footer: AuthAccountFooter(
          prompt: 'New to LittleSteps?',
          actionLabel: 'Create account',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
        ),
      ),
    );
  }
}
