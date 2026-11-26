import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Items in the doctor's slide-out menu.
enum DoctorMenuItem {
  appointments,
  patients,
  prescriptions,
  medicalRecords,
  labResults,
  dashboard,
  profile,
  help,
  logout,
}

/// Drawer opened by the Menu tab.
class DoctorDrawer extends StatelessWidget {
  const DoctorDrawer({super.key, required this.doctorName, required this.specialty, required this.onSelect});

  final String doctorName;
  final String specialty;
  final ValueChanged<DoctorMenuItem> onSelect;

  void _tap(BuildContext context, DoctorMenuItem item) {
    Navigator.of(context).pop(); // close the drawer first
    onSelect(item);
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, DoctorMenuItem item) => ListTile(
          leading: Icon(icon, color: AppColors.navy),
          title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
          onTap: () => _tap(context, item),
          dense: true,
        );

    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 22),
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: AppColors.brandNavy, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(specialty, style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                tile(Icons.event_note_rounded, 'Appointments', DoctorMenuItem.appointments),
                tile(Icons.groups_rounded, 'Patients', DoctorMenuItem.patients),
                tile(Icons.medication_rounded, 'Prescriptions', DoctorMenuItem.prescriptions),
                tile(Icons.folder_shared_rounded, 'Medical Records', DoctorMenuItem.medicalRecords),
                tile(Icons.science_rounded, 'Lab Results', DoctorMenuItem.labResults),
                const Divider(indent: 16, endIndent: 16),
                tile(Icons.dashboard_rounded, 'Dashboard', DoctorMenuItem.dashboard),
                tile(Icons.person_rounded, 'Profile', DoctorMenuItem.profile),
                tile(Icons.help_outline_rounded, 'Help & Support', DoctorMenuItem.help),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
              onTap: () => _tap(context, DoctorMenuItem.logout),
            ),
          ),
        ],
      ),
    );
  }
}
