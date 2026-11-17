import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_notification.dart';
import '../../providers/notification_providers.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/theme/app_spacing.dart';

// The signed-in person's notifications, newest first
class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AsyncView<List<AppNotification>>(
        value: list,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No notifications yet.',
        onRetry: () => ref.invalidate(notificationListProvider),
        builder: (items) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.body),
                  if (item.isUnread)
                    TextButton(
                      onPressed: () => ref.read(notificationListProvider.notifier).markRead(item.id),
                      child: const Text('Mark as read'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}