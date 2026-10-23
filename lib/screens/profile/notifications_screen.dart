import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/user_role.dart';
import '../../services/profile_service.dart';
import '../../widgets/h360_card.dart';

/// Notification toggles (different list per role). Saved on the device.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool>? _values;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ProfileService.instance.loadNotificationPrefs(widget.role);
    if (!mounted) return;
    setState(() => _values = prefs);
  }

  void _toggle(String key, bool value) {
    setState(() => _values = {...?_values, key: value});
    ProfileService.instance.setNotificationPref(widget.role, key, value);
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final options = ProfileService.notificationOptions(widget.role);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: values == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: H360Card(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.title, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                                const SizedBox(height: 2),
                                Text(o.subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Switch(
                            value: values[o.key] ?? true,
                            onChanged: (v) => _toggle(o.key, v),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
