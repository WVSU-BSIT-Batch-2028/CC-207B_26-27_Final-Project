import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/application_details.dart';
import '../models/pharmacy_summary.dart';

// Admin reading of pharmacies and their applications
class AdminPharmacyService {
  AdminPharmacyService(this._client);

  final SupabaseClient _client;

  // The pharmacies table, with an optional status filter and search
  Future<List<PharmacySummary>> list({String? status, String? search}) async {
    final rows = await _client.rpc('admin_list_pharmacies', params: {
      'p_status': status,
      'p_search': search,
    }) as List;
    return rows.map((r) => PharmacySummary.fromJson(r as Map<String, dynamic>)).toList();
  }

  // One application's full details
  Future<ApplicationDetails?> details(String branchId) async {
    final json = await _client.rpc('admin_get_application', params: {'p_branch_id': branchId});
    return json == null ? null : ApplicationDetails.fromJson(json as Map<String, dynamic>);
  }

  // A link to a private document that works for 2 minutes
  Future<String> documentLink(String path) {
    return _client.storage.from('pharmacy-documents').createSignedUrl(path, 120);
  }
}