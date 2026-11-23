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
  bool _bulkBusy = false;

  Future<void> _open(AppNotification item) async {
    if (item.isUnread) {
      await ref.read(notificationListProvider.notifier).markRead(item.id);
    }
    if (!mounted) return;
    widget.onOpen?.call(item);
  }

  Future<void> _markRead(String id) async {
    try {
      await ref.read(notificationListProvider.notifier).markRead(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(notificationListProvider.notifier).deleteNotification(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    try {
      await ref.read(notificationListProvider.notifier).markAllRead();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _clearAll() async {
    if (_bulkBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          'This removes all notifications from your list. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _bulkBusy = true);
    try {
      await ref.read(notificationListProvider.notifier).clearAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationListProvider);
    final unreadCount = list.maybeWhen(
      data: (items) => items.where((item) => item.isUnread).length,
      orElse: () => 0,
    );
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
                      onMarkRead: item.isUnread ? () => _markRead(item.id) : null,
                      onDelete: () => _delete(item.id),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (unreadCount > 0)
                      OutlinedButton.icon(
                        onPressed: _bulkBusy ? null : _markAllRead,
                        icon: _bulkBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.done_all_outlined, size: 18),
                        label: const Text('Mark all as read'),
                      ),
                    if (unreadCount > 0) const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: items.isNotEmpty && !_bulkBusy ? _clearAll : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      label: const Text('Clear notifications'),
                    ),
                  ],
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
  const _NotificationCard({
    required this.item,
    required this.onTap,
    this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;

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
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
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
              const SizedBox(width: 4),
              Column(
                children: [
                  if (onMarkRead != null)
                    IconButton(
                      tooltip: 'Mark as read',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: onMarkRead,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.check_circle,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}