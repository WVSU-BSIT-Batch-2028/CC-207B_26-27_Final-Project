import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/application_details.dart';
import '../models/pharmacy_summary.dart';
import '../models/verification_check.dart';

// Admin reading of pharmacies and their applications
class AdminPharmacyService {
  AdminPharmacyService(this._client);

  final SupabaseClient _client;

  // The pharmacies table, with an optional status filter and search
  Future<List<PharmacySummary>> list({String? status, String? search}) async {
    final rows = await _client.rpc(
      'admin_list_pharmacies',
      params: {'p_status': status, 'p_search': search},
    ) as List;
    return rows
        .map((r) => PharmacySummary.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // One application's full details
  Future<ApplicationDetails?> details(String branchId) async {
    final json = await _client.rpc(
      'admin_get_application',
      params: {'p_branch_id': branchId},
    );
    return json == null
        ? null
        : ApplicationDetails.fromJson(json as Map<String, dynamic>);
  }

  // A link to a private document that works for 2 minutes
  Future<String> documentLink(String path) {
    return _client.storage
        .from('pharmacy-documents')
        .createSignedUrl(path, 120);
  }

  // The official FDA portal address, kept in the database
  Future<String> fdaPortalUrl() async {
    final row = await _client
        .from('official_links')
        .select('url')
        .eq('key', 'fda_verification_portal')
        .single();
    return row['url'] as String;
  }

  // All checks for a pharmacy, newest first
  Future<List<VerificationCheck>> checks(String branchId) async {
    final rows = await _client
        .from('verification_checks')
        .select()
        .eq('subject_type', 'branch')
        .eq('subject_id', branchId)
        .order('checked_at', ascending: false);
    return rows.map((r) => VerificationCheck.fromJson(r)).toList();
  }

  // Is there a "matched" check on the pharmacy's current details?
  Future<bool> hasCurrentMatch(String branchId) async {
    final result = await _client.rpc(
      'branch_has_current_match',
      params: {'p_branch_id': branchId},
    );
    return result as bool;
  }

  // Save a new FDA check
  Future<void> recordCheck(
    String branchId,
    String result,
    String? notes,
  ) async {
    await _client.rpc(
      'record_branch_verification',
      params: {'p_branch_id': branchId, 'p_result': result, 'p_notes': notes},
    );
  }

  // Approve a waiting pharmacy
  Future<void> approve(String branchId) async {
    await _client.rpc('approve_application', params: {'p_branch_id': branchId});
  }

  // Reject a waiting pharmacy with a reason
  Future<void> reject(String branchId, String reason) async {
    await _client.rpc(
      'reject_application',
      params: {'p_branch_id': branchId, 'p_reason': reason},
    );
  }

  // Take an active pharmacy offline, with a reason
  Future<void> deactivate(String branchId, String reason) async {
    await _client.rpc(
      'deactivate_branch',
      params: {'p_branch_id': branchId, 'p_reason': reason},
    );
  }

  // Bring an inactive pharmacy back online
  Future<void> activate(String branchId) async {
    await _client.rpc('activate_branch', params: {'p_branch_id': branchId});
  }

  // Why a pharmacy was deactivated (admins can read pharmacies directly)
  Future<String?> deactivationReason(String branchId) async {
    final row = await _client
        .from('branches')
        .select('deactivation_reason')
        .eq('id', branchId)
        .maybeSingle();
    return row?['deactivation_reason'] as String?;
  }

  // Turn server error codes into messages for the admin
  static String friendlyError(Object error) {
    final text = error is PostgrestException ? error.message : error.toString();

    // Approving and rejecting applications
    if (text.contains('NEEDS_FDA_CHECK')) {
      return 'Record a "Matched and valid" FDA check on the current LTO details first.';
    }
    if (text.contains('NOT_PENDING')) return 'This application was already decided.';
    if (text.contains('LTO_EXPIRED')) return 'This LTO has expired, so it cannot be approved.';
    if (text.contains('REASON_LENGTH')) return 'The reason must be 5 to 200 characters.';
    if (text.contains('NOT_ALLOWED')) return 'Only administrators can do this.';

    // Deactivating and activating pharmacies
    if (text.contains('Only active branches')) return 'Only active pharmacies can be deactivated.';
    if (text.contains('Only inactive branches')) return 'This pharmacy is already active.';
    if (text.contains('Reason must be between')) return 'The reason must be 5 to 200 characters.';
    if (text.contains('Branch not found')) return 'This pharmacy could not be found.';
    if (text.contains('Only administrators')) return 'Only administrators can do this.';

    return 'Something went wrong. Please try again.';
  }
}
