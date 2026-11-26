// Profile page (opened from the top bar or the sidebar): shows who is logged
// in, an Edit profile button, and Log out at the bottom behind a question.

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/info_row.dart';
import '../widgets/responsive_body.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

/// Asks "Log out?" and, if confirmed, logs out and opens the login screen.
/// Used by the Profile page and the sidebar's Log out button.
Future<void> confirmAndLogOut(BuildContext context) async {
  final confirmed = await showConfirmDialog(
    context,
    title: AppStrings.logOutTitle,
    message: AppStrings.logOutMessage,
    confirmLabel: AppStrings.logOut,
  );
  if (!confirmed || !context.mounted) return;
  await AuthService().logOut();
  if (!context.mounted) return;
  showMessage(context, AppStrings.loggedOut);
  // Clear every screen so Back can't return to the app.
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

/// The logged-in user's own profile.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logOut(BuildContext context) => confirmAndLogOut(context);

  /// Opens Edit profile and redraws with the new values when it was saved.
  Future<void> _edit() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (saved == true && mounted) setState(() {});
  }

  /// "farmer" -> "Farmer".
  String _roleLabel(String role) => role[0].toUpperCase() + role.substring(1);

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveBody(
        maxWidth: AppSizes.maxFormWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            // Avatar with the first letter, name, role and town.
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _roleLabel(user.role).toUpperCase(),
                        style: AppTextStyles.eyebrow,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.name.toUpperCase(),
                        style: AppTextStyles.pageTitle.copyWith(fontSize: 25),
                      ),
                      if (user.town.isNotEmpty)
                        Text('${user.town}, Iloilo', style: AppTextStyles.lead),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.fieldGap),
            OutlinedButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
            if (user.about.isNotEmpty) ...[
              const SizedBox(height: AppSizes.fieldGap),
              Text(user.about, style: const TextStyle(fontSize: 15)),
            ],
            const SizedBox(height: AppSizes.sectionGap),
            Card(
              child: Column(
                children: [
                  InfoRow(icon: Icons.email, label: 'Email', value: user.email),
                  InfoRow(
                    icon: Icons.location_on,
                    label: 'Town',
                    value: user.town.isEmpty
                        ? 'Not set'
                        : '${user.town}, Iloilo',
                  ),
                  InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Member since',
                    value: formatDate(user.createdAt),
                  ),
                  if (user.role != UserRole.admin)
                    InfoRow(
                      icon: Icons.info_outline,
                      label: 'Account type',
                      value: user.isFarmer
                          ? 'Farmer: you can list crops and answer buyers'
                          : 'Buyer: you can browse crops and post requests',
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sectionGap * 2),
            // Log out is at the bottom so it is not tapped by mistake.
            OutlinedButton.icon(
              onPressed: () => _logOut(context),
              icon: const Icon(Icons.logout),
              label: const Text(AppStrings.logOut),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
