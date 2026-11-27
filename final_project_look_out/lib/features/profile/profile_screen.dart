import 'package:final_project_look_out/widgets/loader.dart';

import '../../widgets/lookout_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  // final VoidCallback? onMenuPressed;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    // this.onMenuPressed,
  });

  final String name, email, role;

  String get displayName => name.trim().isNotEmpty
      ? name.trim()
      : email.contains('@')
      ? email.split('@').first
      : 'LookOut! user';

  Future<Map<String, dynamic>?> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return userDoc.data();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: LookOutAppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: 'My Profile',
        // onMenuPressed: onMenuPressed,
      ),

      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader.circular();
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load profile information.'),
            );
          }

          final userData = snapshot.data ?? {};

          final profileName = (userData['fullName'] ?? name).toString();
          final profileEmail =
              (userData['email'] ??
                      FirebaseAuth.instance.currentUser?.email ??
                      email)
                  .toString();
          final profileRole = (userData['role'] ?? role).toString();

          final displayName = profileName.trim().isNotEmpty
              ? profileName.trim()
              : profileEmail.contains('@')
              ? profileEmail.split('@').first
              : 'LookOut! user';

          final displayRole = profileRole.trim().isEmpty
              ? 'Not specified'
              : profileRole.trim();

          final initials = displayName
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .map((word) => word[0])
              .take(2)
              .join()
              .toUpperCase();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Profile header
              Card(
                elevation: 2,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Text(
                          initials.isEmpty ? 'U' : initials,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          displayRole.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Account details heading
              Text(
                'Account Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _detail(context, Icons.person_outline, 'Full Name', displayName),

              _detail(
                context,
                Icons.email_outlined,
                'Email Address',
                profileEmail,
              ),

              _detail(
                context,
                Icons.badge_outlined,
                'Account Type',
                displayRole,
              ),

              const SizedBox(height: 16),

              // Information card
              Card(
                elevation: 0,
                color: colors.secondaryContainer.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: colors.onSecondaryContainer,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your LookOut! Account',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Your profile information is displayed '
                              'for this session.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
