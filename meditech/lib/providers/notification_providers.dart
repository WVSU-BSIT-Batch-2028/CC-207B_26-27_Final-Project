import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return SupabaseNotificationService();
});

class NotificationListNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final service = ref.read(notificationServiceProvider);
    final channel = service.watchMine(() {
      if (ref.mounted) ref.invalidateSelf();
    });
    if (channel != null) {
      ref.onDispose(channel.unsubscribe);
    }
    return service.loadMine();
  }

  // Mark one row read, then show it as read right away
  Future<void> markRead(String id) async {
    await ref.read(notificationServiceProvider).markRead(id);
    final current = state.value ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(readAt: DateTime.now().toUtc()) else item,
    ]);
  }

  // Mark every unread row read. Deletes are blocked, so this is "clear".
  Future<void> markAllRead() async {
    final current = state.value ?? [];
    final unread = [for (final item in current) if (item.isUnread) item.id];
    if (unread.isEmpty) return;
    final service = ref.read(notificationServiceProvider);
    final readAt = DateTime.now().toUtc();
    await Future.wait([for (final id in unread) service.markRead(id)]);
    state = AsyncData([
      for (final item in current)
        if (item.isUnread) item.copyWith(readAt: readAt) else item,
    ]);
  }
}

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, List<AppNotification>>(
  NotificationListNotifier.new,
);

// How many of the loaded notifications are still unread
final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationListProvider);
  return list.maybeWhen(
    data: (items) => items.where((item) => item.isUnread).length,
    orElse: () => 0,
  );
});