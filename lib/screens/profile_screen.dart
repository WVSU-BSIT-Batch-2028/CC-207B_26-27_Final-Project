import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';
import '../widgets/feedback_banner.dart';
import '../foodwise_theme.dart';
import '../services/auth_service.dart';
import 'profile_settings_screen.dart';
import 'dietary_settings_screen.dart';
import 'auth/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Future<Map<String, dynamic>?> profileFuture;
  final VoidCallback onRefresh;
  const ProfileScreen({
    super.key,
    required this.profileFuture,
    required this.onRefresh,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingOut = false;
  bool _confirming = false;

  Future<void> _openSettings(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) widget.onRefresh();
  }

  Future<void> _confirmLogout() async {
    if (_signingOut || _confirming) return;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your account. Your saved meals will remain in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FoodWiseColors.error,
              foregroundColor: FoodWiseColors.surface,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || confirmed != true) return;
    setState(() => _signingOut = true);
    try {
      await AuthService.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        AppFeedback.fromError(
          error,
          title: 'Could not sign out',
          fallback: 'Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        key: const PageStorageKey('foodwise-profile'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: FoodWiseTypeSize.pageTitle,
              color: FoodWiseColors.charcoal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: FoodWiseSpacing.lg),
          FutureBuilder<Map<String, dynamic>?>(
            future: widget.profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(FoodWiseSpacing.section),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: FoodWiseColors.orange,
                    ),
                  ),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return FeedbackBanner(
                  feedback: FeedbackData(
                    title: 'Profile could not load',
                    message: snapshot.hasError
                        ? AppFeedback.fromError(
                            snapshot.error!,
                            fallback: 'Check your connection and try again.',
                          ).message
                        : 'Your student profile is not available. Try again or contact support.',
                    type: FeedbackType.error,
                    actionLabel: 'Try again',
                  ),
                  onAction: widget.onRefresh,
                );
              }
              final profile = snapshot.data!;
              final name = (profile['full_name']?.toString() ?? '').trim();
              final role = (profile['role']?.toString() ?? 'student').trim();
              final avatar = (profile['avatar_url']?.toString() ?? '').trim();
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: FoodWiseColors.surface,
                  borderRadius: BorderRadius.circular(FoodWiseRadius.panel),
                  border: Border.all(color: FoodWiseColors.border),
                ),
                child: Column(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 94,
                        height: 94,
                        child: avatar.isEmpty
                            ? _avatarPlaceholder()
                            : Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _avatarPlaceholder(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name.isEmpty ? 'Student' : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: FoodWiseTypeSize.profileTitle,
                        fontWeight: FontWeight.w900,
                        color: FoodWiseColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      role.isEmpty ? 'STUDENT' : role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: FoodWiseTypeSize.caption,
                        fontWeight: FontWeight.w700,
                        color: FoodWiseColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _signingOut
                          ? null
                          : () => _openSettings(const ProfileSettingsScreen()),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: FoodWiseSpacing.xxl),
          _heading('Account'),
          _tile(
            icon: Icons.manage_accounts_outlined,
            title: 'Profile Settings',
            subtitle: 'Manage your personal and account information',
            onTap: () => _openSettings(const ProfileSettingsScreen()),
          ),
          const SizedBox(height: FoodWiseSpacing.xl),
          _heading('Personalization'),
          _tile(
            icon: Icons.restaurant_menu_rounded,
            title: 'Dietary Settings',
            subtitle: 'Manage your food preferences',
            onTap: () => _openSettings(const DietarySettingsScreen()),
          ),
          const SizedBox(height: FoodWiseSpacing.xxl),
          _heading('Session'),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: FoodWiseColors.error,
              side: BorderSide(color: FoodWiseColors.errorBorder),
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _signingOut ? null : _confirmLogout,
            icon: _signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(_signingOut ? 'Signing out…' : 'Sign out'),
          ),
        ],
      ),
    ),
  );

  Widget _avatarPlaceholder() => const ColoredBox(
    color: FoodWiseColors.paleOrange,
    child: Icon(
      Icons.person_rounded,
      size: 54,
      color: FoodWiseColors.deepOrange,
    ),
  );
  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: FoodWiseTypeSize.button,
        color: FoodWiseColors.charcoal,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Material(
    color: FoodWiseColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FoodWiseRadius.control),
      side: const BorderSide(color: FoodWiseColors.border),
    ),
    child: ListTile(
      leading: Icon(icon, color: FoodWiseColors.deepOrange),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: !_signingOut,
      onTap: _signingOut ? null : onTap,
    ),
  );
}
