import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_format.dart';
import '../../models/notification_item.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../services/profile_service.dart';
import '../../widgets/h360_card.dart';
import '../../widgets/notification_target.dart';
import '../../widgets/notifications_preview.dart';
import '../../widgets/state_views.dart';

/// Notification switches per category and the history list. Tap a
/// notification to mark it read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool>? _values;
  List<NotificationItem>? _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ProfileService.instance.loadNotificationPrefs(widget.role);
    final history = await ProfileService.instance.loadNotificationHistory(widget.role);
    if (!mounted) return;
    setState(() {
      _values = prefs;
      _history = history;
    });
  }

  void _toggle(String key, bool value) {
    setState(() => _values = {...?_values, key: value});
    ProfileService.instance.setNotificationPref(widget.role, key, value);
  }

  void _markRead(NotificationItem item) {
    if (item.read) return;
    setState(() {
      _history = [
        for (final n in _history ?? <NotificationItem>[]) n.id == item.id ? n.copyWith(read: true) : n,
      ];
    });
    ProfileService.instance.markNotificationsRead(widget.role, [item.id]);
  }

  void _markAllRead() {
    final history = _history ?? <NotificationItem>[];
    setState(() => _history = [for (final n in history) n.copyWith(read: true)]);
    ProfileService.instance.markNotificationsRead(widget.role, [for (final n in history) n.id]);
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
      );

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final history = _history;
    final options = ProfileService.notificationOptions(widget.role);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: (values == null || history == null)
          ? const Center(child: CircularProgressIndicator())
          : _content(values, history, options),
    );
  }

  Widget _content(Map<String, bool> values, List<NotificationItem> history, List<NotificationOption> options) {
    // Hide categories that are switched off.
    final visible = [for (final n in history) if (values[n.categoryKey] ?? true) n];
    final hasUnread = visible.any((n) => !n.read);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
      children: [
        _heading('Settings'),
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
                        Text(o.subtitle, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
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
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _heading('Recent notifications')),
            if (hasUnread)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: _markAllRead,
                  child: const Text('Mark all as read', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        if (visible.isEmpty)
          const EmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'No notifications',
            message: 'Nothing to show here. Switch a category on above to see its notifications.',
          )
        else
          for (final n in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationTile(
                item: n,
                icon: notificationIcon(n.categoryKey),
                onTap: () {
                  _markRead(n);
                  openNotificationTarget(context, n);
                },
              ),
            ),
      ],
    );
  }
}

/// One past notification. Unread ones are bold with a dot.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.icon, required this.onTap});

  final NotificationItem item;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.read ? "" : "Unread. "}${item.title}. ${item.message}',
      child: H360Card(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      if (!item.read)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(item.message, style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    formatActivityTime(item.time),
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}