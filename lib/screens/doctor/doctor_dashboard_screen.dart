import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/doctor_dashboard_data.dart';
import '../../services/dashboard_service.dart';
import '../../services/doctor_service.dart';
import 'doctor_prescriptions_screen.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/h360_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

/// Doctor "Dashboard" page from the prototype: six shortcuts + Recent Activity.
/// Opened from the drawer (Menu > Dashboard) or "Full dashboard" on Home.
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate; // shell tab index

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  late Future<DoctorDashboardData> _future = DoctorService.instance.fetchDashboard();

  void _retry() => setState(() => _future = DoctorService.instance.fetchDashboard());

  /// Closes this page, then switches the shell tab.
  void _goTab(int index) {
    Navigator.of(context).pop();
    widget.onNavigate(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Dashboard'),
      ),
      body: FutureBuilder<DoctorDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 96)),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: SkeletonBox(height: 96)),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  SkeletonBox(height: 200),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is DashboardException
                ? error.message
                : 'Something unexpected happened. Please try again.';
            return ListView(children: [ErrorState(message: message, onRetry: _retry)]);
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
            children: [
              FadeSlideIn(
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.45,
                  children: [
                    _ActionTile(icon: Icons.event_note_rounded, label: 'Appointments', onTap: () => _goTab(1)),
                    _ActionTile(icon: Icons.groups_rounded, label: 'Patients', onTap: () => _goTab(2)),
                    _ActionTile(
                      icon: Icons.medication_rounded,
                      label: 'Prescriptions',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const DoctorPrescriptionsScreen()),
                      ),
                    ),
                    _ActionTile(
                      icon: Icons.folder_shared_rounded,
                      label: 'Medical Records',
                      // Records are opened per patient, from the Patients tab.
                      onTap: () => _goTab(2),
                    ),
                    _ActionTile(
                      icon: Icons.science_rounded,
                      label: 'Lab Results',
                      onTap: () => _goTab(2),
                    ),
                    _ActionTile(icon: Icons.person_rounded, label: 'Profile', onTap: () => _goTab(3)),
                  ],
                ),
              ),
              const SectionHeader(title: 'Recent Activity'),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: data.activities.isEmpty
                    ? H360Card(
                        child: Row(
                          children: [
                            Icon(Icons.inbox_rounded, color: AppColors.textMuted),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('No recent activity yet.', style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      )
                    : H360Card(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            for (var i = 0; i < data.activities.length; i++) ...[
                              _ActivityRow(item: data.activities[i]),
                              if (i != data.activities.length - 1) Divider(height: 1, color: AppColors.border),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final ActivityItem item;

  IconData get _icon {
    switch (item.type) {
      case ActivityType.labResult:
        return Icons.science_rounded;
      case ActivityType.prescription:
        return Icons.medication_rounded;
      case ActivityType.message:
        return Icons.chat_bubble_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.brandNavy, shape: BoxShape.circle),
            child: Icon(_icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(item.subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          Text(item.time, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
