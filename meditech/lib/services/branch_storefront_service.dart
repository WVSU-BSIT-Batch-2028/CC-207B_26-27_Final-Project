import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';

/// Owner replaces the branch storefront photo shown to customers.
class BranchStorefrontService {
  BranchStorefrontService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> uploadStorefront({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw const AppFailure('Choose a photo first.');
    }
    final branchId = await _client.rpc('my_branch_id') as String?;
    if (branchId == null) {
      throw const AppFailure('Could not resolve your branch.');
    }

    final ext = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$branchId/storefront/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('pharmacy-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    await _client.rpc('owner_update_storefront', params: {
      'p_path': path,
      'p_mime': mimeType,
      'p_size': bytes.length,
    });
  }
}