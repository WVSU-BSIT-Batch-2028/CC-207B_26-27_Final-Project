import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/local_bus_tracking_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/lookout_app_bar.dart';
import '../../widgets/lookout_bottom_nav.dart';
import '../../widgets/lookout_drawer.dart';
import '../about/about_screen.dart';
import '../admin_exclusive/accounts/accounts_screen.dart';
import '../admin_exclusive/feedbacks_faqs/feedback_faqs.dart';
import '../admin_exclusive/logs/logs_screen.dart';
import '../analytics/analytics_screen.dart';
import '../announcements/announcements_screen.dart';
import '../landing/landing_screen.dart';
import '../profile/profile_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // App Bar
      appBar: selectedIndex == 0
          ? const LookOutAppBar(title: 'Admin Dashboard')
          : null,

      key: _scaffoldKey,
      drawer: LookOutDrawer(
        header: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset('assets/images/lookoutBanner.png', height: 60),
        ),
        items: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(
                    name: 'Commuter',
                    email: 'commuter@lookout.ph',
                    role: 'commuter',
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.account_box_sharp),
            title: const Text('Accounts'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountsScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Feedbacks FAQs'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedbackFaqsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Logs'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Announcement'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnnouncementsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => const ConfirmationDialog(
                  title: 'Log Out',
                  content: 'Are you sure you want to log out?',
                  confirmText: 'Log Out',
                ),
              );

              if (confirmed != true || !context.mounted) return;

              Navigator.pop(context); // Close drawer

              try {
                await AuthService().signOut();

                if (!context.mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LandingScreen(),
                  ),
                  (route) => false,
                );

                // Show success notification on LandingScreen
                PopupNotif(
                  title: 'Success',
                  message: 'You have successfully logged out.',
                  type: NotifType.success,
                ).show(context);
              } catch (e) {
                if (!context.mounted) return;

                PopupNotif(
                  title: 'Error',
                  message: 'Failed to log out. Please try again.',
                  type: NotifType.error,
                ).show(context);
              }
            },
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: LookOutBottomNav(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_box_outlined),
            selectedIcon: Icon(Icons.account_box),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.feedback_outlined),
            selectedIcon: Icon(Icons.feedback),
            label: 'Feedbacks FAQs',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Announcements',
          ),
        ],
      ),

      // Dashboard Body
      body: IndexedStack(
        index: selectedIndex,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Text('Welcome, Admin!', style: theme.textTheme.headlineMedium),

                const SizedBox(height: 6),

                Text(
                  'Manage and monitor your LookOut! system.',
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 24),

                // System Overview
                Text(
                  'System Overview',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Unable to load system overview: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Loader.circular();
                    }

                    var driverCount = 0;
                    final registeredPlates = <String>{};
                    for (final user in snapshot.data!.docs) {
                      final data = user.data();
                      if ((data['role'] as String?)?.trim().toLowerCase() ==
                          'driver') {
                        driverCount++;
                        final plates = data['plates'];
                        if (plates is Iterable) {
                          registeredPlates.addAll(
                            plates
                                .whereType<String>()
                                .where((plate) => plate.isNotEmpty)
                                .map((plate) => plate.toUpperCase()),
                          );
                        }
                        final activePlate = data['activePlate'];
                        if (activePlate is String && activePlate.isNotEmpty) {
                          registeredPlates.add(activePlate.toUpperCase());
                        }
                      }
                    }

                    return ValueListenableBuilder<List<ActiveBus>>(
                      valueListenable:
                          LocalBusTrackingService.instance.activeBuses,
                      builder: (context, activeBuses, _) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          AdminSummaryCard(
                            title: 'Total Users',
                            value: '${snapshot.data!.docs.length}',
                            icon: Icons.people_outline,
                          ),
                          AdminSummaryCard(
                            title: 'Total Drivers',
                            value: '$driverCount',
                            icon: Icons.person_outline,
                          ),
                          AdminSummaryCard(
                            title: 'Registered Vehicles',
                            value: '${registeredPlates.length}',
                            icon: Icons.directions_bus_outlined,
                          ),
                          AdminSummaryCard(
                            title: 'Active Rides (this device)',
                            value:
                                '${activeBuses.where((bus) => bus.isActive).length}',
                            icon: Icons.route_outlined,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Management Section
                Text(
                  'Management',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // User Accounts
                _buildManagementCard(
                  context,
                  icon: Icons.manage_accounts_outlined,
                  title: 'User Accounts',
                  subtitle: 'Manage registered user accounts',
                  onTap: () => setState(() => selectedIndex = 1),
                ),

                // Feedback and FAQs
                _buildManagementCard(
                  context,
                  icon: Icons.feedback_outlined,
                  title: 'Feedback and FAQs',
                  subtitle: 'Review feedback and frequently asked questions',
                  onTap: () => setState(() => selectedIndex = 2),
                ),

                // Activity Logs
                _buildManagementCard(
                  context,
                  icon: Icons.history,
                  title: 'Activity Logs',
                  subtitle: 'Monitor recorded system activities',
                  onTap: () => setState(() => selectedIndex = 3),
                ),

                _buildManagementCard(
                  context,
                  icon: Icons.campaign_outlined,
                  title: 'Announcements',
                  subtitle: 'View service and project updates',
                  onTap: () => setState(() => selectedIndex = 4),
                ),

                const SizedBox(height: 20),

                // Recent Activity Section
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('logs')
                      .orderBy('createdAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Unable to load recent activity: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Loader.circular();
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return const Card(
                        child: ListTile(
                          leading: Icon(Icons.history),
                          title: Text('No activity has been recorded.'),
                        ),
                      );
                    }
                    return Card(
                      child: Column(
                        children: snapshot.data!.docs.map((log) {
                          final data = log.data();
                          final createdAt = data['createdAt'];
                          final dateLabel = createdAt is Timestamp
                              ? createdAt
                                    .toDate()
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16)
                              : 'Time unavailable';
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(data['title'] as String? ?? 'Activity'),
                            subtitle: Text(
                              '${data['description'] as String? ?? ''}\n$dateLabel',
                            ),
                            isThreeLine: true,
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          AccountsScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          FeedbackFaqsScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          LogsScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          AnnouncementsScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
    );
  }

  // Reusable Management Card
  Widget _buildManagementCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

// Reusable Admin Summary Card
class AdminSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const AdminSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Card(
        elevation: 1,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),

              const SizedBox(height: 14),

              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(title, style: theme.textTheme.bodySmall, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}
