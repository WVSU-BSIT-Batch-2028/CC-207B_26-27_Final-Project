import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lto_renewal.dart';
import '../models/pharmacy_application.dart';

// Renewed Licenses to Operate: suspended owners send them, admins review them
class LtoRenewalService {
  LtoRenewalService(this._client);

  final SupabaseClient _client;

  static const _bucket = 'pharmacy-documents';

  // The signed-in owner's pharmacy (owners can read their own branch)
  Future<OwnBranch?> myBranch() async {
    final branchId = await _client.rpc('my_branch_id') as String?;
    if (branchId == null) return null;
    final row = await _client
        .from('branches')
        .select('id, display_id, pharmacy_name, branch_name, status, deactivation_reason, lto_number, lto_expiry')
        .eq('id', branchId)
        .maybeSingle();
    return row == null ? null : OwnBranch.fromJson(row);
  }

  // The newest renewal for a pharmacy, if any
  Future<LtoRenewal?> latestFor(String branchId) async {
    final row = await _client
        .from('lto_renewals')
        .select('id, lto_number, lto_expiry, storage_path, mime_type, status, review_reason, created_at')
        .eq('branch_id', branchId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : LtoRenewal.fromJson(row);
  }

  // Upload the file into the pharmacy's own folder, then send the renewal
  Future<void> submit({
    required String branchId,
    required String ltoNumber,
    required DateTime ltoExpiry,
    required PickedDocument file,
  }) async {
    final ext = switch (file.mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    };
    final path = '$branchId/lto_renewal/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(_bucket)
        .uploadBinary(path, file.bytes, fileOptions: FileOptions(contentType: file.mimeType));

    final expiry = ltoExpiry.toIso8601String().substring(0, 10); // yyyy-MM-dd
    await _client.rpc('submit_lto_renewal', params: {
      'p': {
        'lto_number': ltoNumber.trim(),
        'lto_expiry': expiry,
        'storage_path': path,
        'mime_type': file.mimeType,
        'size_bytes': file.bytes.length,
      },
    });
  }

  // A link to the renewal file that works for 2 minutes
  Future<String> fileLink(String path) => _client.storage.from(_bucket).createSignedUrl(path, 120);

  // The admin accepts or rejects (with a reason) a renewal
  Future<void> review(String renewalId, {required bool accept, String? reason}) async {
    await _client.rpc('review_lto_renewal', params: {
      'p_renewal_id': renewalId,
      'p_accept': accept,
      'p_reason': reason,
    });
  }

  // Turn server error codes into plain messages
  static String friendlyError(Object error) {
    if (error is StorageException) return 'The file could not be uploaded. Please try again.';
    final text = error is PostgrestException ? error.message : error.toString();

    // Sending a renewal
    if (text.contains('NOT_INACTIVE')) return 'Your pharmacy is already online.';
    if (text.contains('LTO_EXPIRED')) return 'This LTO has already expired.';
    if (text.contains('BAD_DOCUMENT_PATH')) return 'The file could not be saved. Please try again.';
    if (text.contains('one_pending_renewal')) return 'A renewal is already waiting for review.';

    // Reviewing a renewal
    if (text.contains('NOT_PENDING')) return 'This renewal was already reviewed.';
    if (text.contains('NOT_FOUND')) return 'This renewal could not be found.';
    if (text.contains('REASON_LENGTH')) return 'The reason must be 5 to 200 characters.';
    if (text.contains('lto_number')) return 'Another pharmacy already uses this LTO number.';

    if (text.contains('NOT_ALLOWED')) return 'You are not allowed to do this.';
    return 'Something went wrong. Please try again.';
  }
}
