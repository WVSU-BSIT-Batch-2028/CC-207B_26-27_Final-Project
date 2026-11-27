import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../services/doctor_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/hero_panel.dart';
import '../../widgets/menu_tile.dart';
import '../../widgets/state_views.dart';
import 'help_support_screen.dart';
import 'logout_dialog.dart';
import 'notifications_screen.dart';
import 'personal_info_screen.dart';
import 'preference_sheets.dart';

/// Profile tab for both roles: Personal Information, Notifications,
/// App Theme, Help & Support and Log Out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;

  bool get _isDoctor => widget.role == UserRole.doctor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileService.instance.load(widget.role);
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  /// Header name: "Dr. <LastName>" for doctors, full name for patients.
  String _headerName(UserProfile p) {
    if (!_isDoctor) return p.fullName;
    final clean = p.fullName.replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '').trim();
    if (clean.isEmpty) return 'Doctor';
    final parts = clean.split(RegExp(r'\s+'));
    return 'Dr. ${parts.last}';
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    _load(); // pick up any edits made on the next screen
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final profile = _profile;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (profile == null)
            const SkeletonBox(height: 176, radius: AppRadius.lg)
          else
            FadeSlideIn(
              child: HeroPanel(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                        ),
                        child: const Icon(Icons.person_outline_rounded, size: 46, color: AppColors.brandNavy),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _headerName(profile),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isDoctor ? DoctorService.specialty : profile.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.badge_outlined,
                  title: 'Personal Information',
                  onTap: () => _push(PersonalInfoScreen(role: role)),
                ),
                MenuTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: () => _push(NotificationsScreen(role: role)),
                ),
                ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) => MenuTile(
                    icon: Icons.palette_outlined,
                    title: 'App Theme',
                    subtitle: '${ThemeController.instance.isDark ? "Dark" : "Light"} · ${ThemeController.instance.textSize.label} text',
                    onTap: () => showThemeSheet(context),
                  ),
                ),
                MenuTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Help & Support',
                  onTap: () => _push(HelpSupportScreen(role: role)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.4),
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}