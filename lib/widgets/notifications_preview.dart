import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/date_format.dart';
import '../models/notification_item.dart';
import '../models/user_role.dart';
import '../screens/profile/notifications_screen.dart';
import '../services/profile_service.dart';
import 'h360_card.dart';
import 'section_header.dart';
import 'state_views.dart';

/// Icon for each notification category key (patient and doctor keys).
/// Shared by this card and the Notifications screen.
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

/// The "Notifications" area on the patient and doctor Home screens.
///
/// Shows TODAY's notifications only: how many are new and the 3 most recent.
/// Older ones are in Profile > Notifications ("See all"). Each has
/// a "Mark as done" check, so the user can see what still needs attention.
/// It reads the same history and category switches as Profile >
/// Notifications (ProfileService), so marking one here marks it there too.
/// "See all" opens that screen.
class NotificationsPreview extends StatefulWidget {
  const NotificationsPreview({super.key, required this.role, this.refreshToken = 0});

  final UserRole role;

  /// Changed by the Home screen whenever it reloads, so this card reloads too.
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

  /// Loads the history, keeping only the categories switched on in
  /// Profile > Notifications (same rule as that screen).
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

  /// "Mark as done": saved on the device, like on the Notifications screen.
  void _markDone(NotificationItem item) {
    if (item.read) return;
    setState(() {
      _items = [for (final n in _items) n.id == item.id ? n.copyWith(read: true) : n];
    });
    ProfileService.instance.markNotificationsRead(widget.role, [item.id]);
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
                      ? 'Today · all done'
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
              child: _PreviewRow(item: n, onDone: () => _markDone(n)),
            ),
      ],
    );
  }
}

/// One notification with its "Mark as done" check.
/// Text AND icon show the state, never colour alone.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.item, required this.onDone});

  final NotificationItem item;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final done = item.read;

    return H360Card(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
          // Mark as done / Done
          done
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success),
                      Text('Done', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : TextButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.radio_button_unchecked_rounded, size: 20),
                  label: const Text('Mark as done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
        ],
      ),
    );
  }
}
