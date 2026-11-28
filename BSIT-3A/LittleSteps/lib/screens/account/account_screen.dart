import 'package:flutter/material.dart';

import '../../config/external_links.dart';
import '../../routing/app_router.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';

/// Caregiver account and settings screen.
///
/// Surfaces session details, sign-out action, privacy notice, and help.
class AccountScreen extends StatelessWidget {
  /// Creates an [AccountScreen].
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionState = AuthScope.maybeOf(context);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;
    final email = sessionState?.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ResponsiveContentBox(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            // Account Header Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.softGreen,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.forest,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuthenticated
                                ? 'Signed in'
                                : 'Guest / Not signed in',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          Text(
                            isAuthenticated && email != null && email.isNotEmpty
                                ? email
                                : 'Sign in to sync your child records.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Sign In or Sign Out Action
            if (isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Sign out'),
                subtitle: const Text(
                  'Clears child session and active records on this device.',
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text(
                        'Your child records will remain safe in the cloud. You will need to sign in again to view them.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await sessionState?.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.home,
                        (route) => false,
                      );
                    }
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.login, color: AppColors.forest),
                title: const Text('Sign in'),
                subtitle: const Text('Sign in with your caregiver account.'),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.signIn);
                },
              ),

            const Divider(),

            // Settings & Privacy Links
            ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.forest,
              ),
              title: const Text('Privacy notice'),
              subtitle: const Text('How LittleSteps protects child records.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.register);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.forest),
              title: const Text('Help & support'),
              subtitle: const Text('Questions and non-diagnostic guidance.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Support: ${AppLinks.githubOrg}'),
                    duration: AppMotion.snackbarDefault,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
