import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';

/// Owner or pharmacist replaces the branch storefront photo shown to customers.
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
    final userId = _client.auth.currentUser?.id;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final filePart = 'storefront_$stamp.$ext';
    final path = userId != null
        ? '$branchId/storefront/$userId/$filePart'
        : '$branchId/storefront/$filePart';

    await _client.storage.from('pharmacy-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    // Also mirror to public staff-avatars under {branchId}/{userId}/{filePart}
    // so unauthenticated guests & customers can always render the storefront photo.
    if (userId != null) {
      try {
        await _client.storage.from('staff-avatars').uploadBinary(
              '$branchId/$userId/$filePart',
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );
      } catch (_) {}
    }

    await _client.rpc('owner_update_storefront', params: {
      'p_path': path,
      'p_mime': mimeType,
      'p_size': bytes.length,
    });
  }
}