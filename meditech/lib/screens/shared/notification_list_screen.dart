import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../providers/notification_providers.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/theme/app_colors.dart';
import '../../widgets/theme/app_spacing.dart';

// The signed-in person's notifications, newest first
class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key, this.onOpen});

  // Customer app opens the linked reservation. Other apps only mark the row read.
  final void Function(AppNotification item)? onOpen;

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {
  static const _recentLimit = 4;
  bool _showAll = false;

  Future<void> _open(AppNotification item) async {
    if (item.isUnread) {
      await ref.read(notificationListProvider.notifier).markRead(item.id);
    }
    if (!mounted) return;
    widget.onOpen?.call(item);
  }

  Future<void> _clear() async {
    try {
      await ref.read(notificationListProvider.notifier).markAllRead();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationListProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: AsyncView<List<AppNotification>>(
        value: list,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No notifications yet.',
        onRetry: () => ref.invalidate(notificationListProvider),
        builder: (items) {
          final visible = _showAll ? items : items.take(_recentLimit).toList();
          final canExpand = items.length > _recentLimit;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (canExpand)
                      TextButton(
                        onPressed: () => setState(() => _showAll = !_showAll),
                        child: Text(_showAll ? 'Show recent' : 'View all'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _NotificationCard(
                      item: item,
                      onTap: () => _open(item),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: OutlinedButton(
                  onPressed: items.any((item) => item.isUnread) ? _clear : null,
                  child: const Text('Clear Notifications'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTone {
  const _NotificationTone({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

_NotificationTone _toneFor(String type) {
  switch (type) {
    case 'reservation_ready':
    case 'reservation_confirmed':
    case 'reservation_completed':
      return const _NotificationTone(
        background: AppColors.primaryLight,
        foreground: AppColors.primary,
        icon: Icons.check_circle_outline,
      );
    case 'new_reservation':
    case 'reservation_reminder':
      return const _NotificationTone(
        background: AppColors.warningLight,
        foreground: AppColors.warning,
        icon: Icons.schedule,
      );
    case 'reservation_expired':
    case 'reservation_cancelled':
    case 'reservation_rejected':
      return const _NotificationTone(
        background: AppColors.neutralLight,
        foreground: AppColors.neutral,
        icon: Icons.cancel_outlined,
      );
    default:
      return const _NotificationTone(
        background: Color(0xFFF7F8F7),
        foreground: AppColors.primary,
        icon: Icons.notifications_none,
      );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(item.type);
    final when = DateFormat('MMM d, yyyy · h:mm a').format(item.createdAt.toLocal());

    return Material(
      color: tone.background,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(tone.icon, size: 18, color: tone.foreground),
              ),
              const SizedBox(width: AppSpacing.md),
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
                              fontWeight: item.isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.text,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (item.isUnread)
                          const Tooltip(
                            message: 'Unread',
                            child: Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      when,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
