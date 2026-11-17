import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_log_entry.dart';
import '../services/activity_log_service.dart';

final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  return SupabaseActivityLogService();
});

final activityLogProvider = FutureProvider<List<ActivityLogEntry>>((ref) {
  return ref.watch(activityLogServiceProvider).loadMine();
});