import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

// Loads notifications and marks one as read
abstract class NotificationService {
  Future<List<AppNotification>> loadMine();
  Future<void> markRead(String id);
  RealtimeChannel? watchMine(void Function() onChange);
}

class SupabaseNotificationService implements NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<AppNotification>> loadMine() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return [];

    final rows = await _client
        .from('notifications')
        .select('id, title, body, read_at, created_at')
        .eq('recipient_id', id)
        .order('created_at', ascending: false);
    return [for (final row in rows) AppNotification.fromJson(row)];
  }

  // Save the read time only. The database blocks every other column.
  @override
  Future<void> markRead(String id) async {
    await _client.from('notifications').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // Ask Supabase to call back when this person's notifications change
  @override
  RealtimeChannel? watchMine(void Function() onChange) {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return _client
        .channel('notifications:$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: id,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}