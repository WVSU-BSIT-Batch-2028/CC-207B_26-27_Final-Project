import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_overview.dart';

// Loads the admin overview in one call
class AdminOverviewService {
  AdminOverviewService(this._client);

  final SupabaseClient _client;

  Future<AdminOverview?> load() async {
    final json = await _client.rpc('admin_overview');
    return json == null ? null : AdminOverview.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

final adminOverviewServiceProvider = Provider<AdminOverviewService>(
  (ref) => AdminOverviewService(Supabase.instance.client),
);

// The overview; reloads each time the screen opens
final adminOverviewProvider = FutureProvider.autoDispose<AdminOverview?>(
  (ref) => ref.read(adminOverviewServiceProvider).load(),
);