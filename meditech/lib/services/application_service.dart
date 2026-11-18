import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/application_status.dart';

// Reads the signed-in owner's own pharmacy application
class ApplicationService {
  ApplicationService(this._client);

  final SupabaseClient _client;

  // The access rules return only this owner's branch, so no filter is needed
  Future<ApplicationStatus?> myApplication() async {
    final row = await _client
        .from('branches')
        .select('display_id, pharmacy_name, branch_name, status, '
            'submitted_at, approved_at, rejection_reason')
        .maybeSingle();
    return row == null ? null : ApplicationStatus.fromJson(row);
  }
}