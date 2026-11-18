import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_log_entry.dart';

// Loads the signed-in owner's branch activity log
abstract class ActivityLogService {
  Future<List<ActivityLogEntry>> loadMine();
}

class SupabaseActivityLogService implements ActivityLogService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<ActivityLogEntry>> loadMine() async {
    final rows = await _client
        .from('activity_log')
        .select('id, actor_label, actor_role, action, entity_type, entity_id, created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final row in rows) ActivityLogEntry.fromJson(row)];
  }
}