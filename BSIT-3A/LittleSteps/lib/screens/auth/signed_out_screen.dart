import 'package:flutter/material.dart';

import '../../routing/app_router.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import 'widgets/auth_widgets.dart';

/// Screen displayed when a caregiver session expires.
///
/// Displays [message], preserves any unsaved draft stored in [AuthScope], and
/// provides a direct action to sign in again.
class SignedOutScreen extends StatelessWidget {
  /// Creates a [SignedOutScreen] with optional [message].
  const SignedOutScreen({
    super.key,
    this.message = 'Please sign in again to continue',
  });

  /// Explanatory message for the signed-out state.
  final String message;

  static const List<String> _desktopHighlights = [
    'Your account data stays protected.',
    'Unsaved drafts are kept until you sign back in.',
    'Pick up right where you left off.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionState = AuthScope.maybeOf(context);
    final draft = sessionState?.unsavedDraft;

    return Scaffold(
      body: AuthResponsiveLayout(
        panelTitle: 'Session ended',
        panelSubtitle: 'Sign back in to keep planning play activities and recording notes for your child.',
        panelHighlights: _desktopHighlights,
        wideFormMaxWidth: 420,
        card: AuthFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                size: 48,
                color: AppColors.forest,
              ),
              const SizedBox(height: AppSpacing.space12),
              Text(
                'Signed out',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (draft != null && draft.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space16),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCanvas,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.save_outlined,
                            size: 18,
                            color: AppColors.forest,
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          Expanded(
                            child: Text(
                              'Your unsaved draft is safe',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        draft,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space20),
              AuthSubmitButton(
                label: 'Sign in again',
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.signIn,
                    arguments: message,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
