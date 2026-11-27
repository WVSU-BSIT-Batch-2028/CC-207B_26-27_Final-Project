import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/date_format.dart';
import '../models/notification_item.dart';
import '../models/user_role.dart';
import '../screens/profile/notifications_screen.dart';
import '../services/profile_service.dart';
import 'h360_card.dart';
import 'notification_target.dart';
import 'section_header.dart';
import 'state_views.dart';

/// Icon for a notification category (also used by the Notifications screen).
IconData notificationIcon(String key) {
  switch (key) {
    case 'appointments':
    case 'appointment':
      return Icons.event_available_rounded;
    case 'prescriptions':
    case 'prescription':
      return Icons.medication_rounded;
    case 'lab_results':
    case 'lab':
      return Icons.science_rounded;
    case 'health':
      return Icons.favorite_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

/// Notifications card on both Home screens: today's notifications only,
/// the 3 newest. Tapping one marks it read and opens its screen, if any.
/// "See all" opens Profile > Notifications.
class NotificationsPreview extends StatefulWidget {
  const NotificationsPreview({super.key, required this.role, this.refreshToken = 0});

  final UserRole role;

  /// Changed by Home on every reload, so this card reloads too.
  final int refreshToken;

  @override
  State<NotificationsPreview> createState() => _NotificationsPreviewState();
}

class _NotificationsPreviewState extends State<NotificationsPreview> {
  static const int _shown = 3;

  bool _loading = true;
  bool _failed = false;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NotificationsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _load();
  }

  /// Loads today's notifications from categories that are switched on.
  Future<void> _load() async {
    try {
      final prefs = await ProfileService.instance.loadNotificationPrefs(widget.role);
      final history = await ProfileService.instance.loadNotificationHistory(widget.role);
      if (!mounted) return;
      setState(() {
        final now = DateTime.now();
        bool isToday(DateTime t) =>
            t.year == now.year && t.month == now.month && t.day == now.day;
        _items = [
          for (final n in history)
            if ((prefs[n.categoryKey] ?? true) && isToday(n.time)) n,
        ];
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Marks the notification as read and opens its screen, if it has one.
  void _open(NotificationItem item) {
    if (!item.read) {
      setState(() {
        _items = [for (final n in _items) n.id == item.id ? n.copyWith(read: true) : n];
      });
      ProfileService.instance.markNotificationsRead(widget.role, [item.id]);
    }
    openNotificationTarget(context, item);
  }

  Future<void> _openAll() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NotificationsScreen(role: widget.role)),
    );
    if (mounted) _load(); // items may have been marked there
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.read).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Notifications',
          subtitle: _loading || _failed
              ? null
              : _items.isEmpty
                  ? 'Today'
                  : unread == 0
                      ? 'Today'
                      : 'Today · $unread new',
          actionLabel: 'See all',
          onAction: _openAll,
        ),
        if (_loading)
          const SkeletonBox(height: 88, radius: AppRadius.md)
        else if (_failed)
          ErrorState(message: "We couldn't load your notifications.", onRetry: _load)
        else if (_items.isEmpty)
          H360Card(
            child: Row(
              children: [
                Icon(Icons.notifications_none_rounded, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No notifications today. Tap "See all" for earlier ones.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          for (final n in _items.take(_shown))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PreviewRow(item: n, onTap: () => _open(n)),
            ),
      ],
    );
  }
}

/// One notification: bold with a dot while unread; chevron if it opens a screen.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = item.read;

    return H360Card(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: done ? 0.06 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(notificationIcon(item.categoryKey), size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: done ? FontWeight.w600 : FontWeight.w800,
                    color: done ? AppColors.textMuted : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.35, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  formatActivityTime(item.time),
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Unread dot, and a chevron when tapping opens a screen.
          if (!done)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
          if (item.target != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}