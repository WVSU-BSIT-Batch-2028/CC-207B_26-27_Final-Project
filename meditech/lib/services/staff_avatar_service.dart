import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';
import 'staff_avatar_local_store.dart';

const staffAvatarsBucket = 'staff-avatars';

String? staffAvatarPublicUrl(String? path, {int? cacheBust}) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:') ||
      path.startsWith('http://') ||
      path.startsWith('https://')) {
    return path;
  }
  try {
    final base = Supabase.instance.client.storage
        .from(staffAvatarsBucket)
        .getPublicUrl(path);
    if (cacheBust == null) return base;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}v=$cacheBust';
  } catch (_) {
    return null;
  }
}

/// Branch owner uploads profile photos for staff (path: branchId/accountId/avatar.ext).
class StaffAvatarService {
  StaffAvatarService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? publicUrlForPath(String? path, {int? cacheBust}) =>
      staffAvatarPublicUrl(path, cacheBust: cacheBust);

  /// Returns the storage object path saved on [staff_members.avatar_path].
  Future<String?> uploadForEmployee({
    required String employeeAccountId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;

    final branchId = await _client.rpc('my_branch_id') as String?;
    if (branchId == null) {
      throw const AppFailure('Could not resolve your branch.');
    }

    final role = await _client.rpc('my_staff_role') as String?;
    if (role != 'owner') {
      throw const AppFailure('Only the branch owner can set employee photos.');
    }

    final ext = _extensionForName(fileName);
    final path = '$branchId/$employeeAccountId/avatar.$ext';

    try {
      await _uploadToBucket(path, bytes, ext);
    } on StorageException catch (error) {
      if (!_bucketMissing(error)) rethrow;
      return _saveInlinePhoto(
        accountId: employeeAccountId,
        ext: ext,
        bytes: bytes,
      );
    }

    await _saveAvatarPath(employeeAccountId, path);
    return path;
  }

  /// Signed-in staff member uploads their own photo.
  Future<String?> uploadOwn({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final accountId = _client.auth.currentUser?.id;
    if (accountId == null) {
      throw const AppFailure('Sign in to update your photo.');
    }
    if (bytes.isEmpty) return null;

    final branchId = await _client.rpc('my_branch_id') as String?;
    if (branchId == null) {
      throw const AppFailure('Could not resolve your branch.');
    }

    final ext = _extensionForName(fileName);
    final path = '$branchId/$accountId/avatar.$ext';

    try {
      await _uploadToBucket(path, bytes, ext);
    } on StorageException catch (error) {
      if (!_bucketMissing(error)) throw AppFailure(error.message);
      return _saveInlinePhoto(accountId: accountId, ext: ext, bytes: bytes);
    }

    await _saveAvatarPath(accountId, path);
    return path;
  }

  Future<void> _uploadToBucket(String path, Uint8List bytes, String ext) {
    return _client.storage.from(staffAvatarsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _mimeFor(ext),
          ),
        );
  }

  bool _bucketMissing(StorageException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == '404' || message.contains('bucket not found');
  }

  /// Used when the storage bucket has not been created yet.
  Future<String> _saveInlinePhoto({
    required String accountId,
    required String ext,
    required Uint8List bytes,
  }) async {
    if (bytes.length > 1500000) {
      throw const AppFailure('Choose a photo smaller than 1.5 MB.');
    }
    final dataUrl = 'data:${_mimeFor(ext)};base64,${base64Encode(bytes)}';
    await _saveAvatarPath(accountId, dataUrl);
    return dataUrl;
  }

  Future<void> _saveAvatarPath(String accountId, String path) async {
    try {
      final rows = await _client
          .from('staff_members')
          .update({'avatar_path': path})
          .eq('account_id', accountId)
          .select('account_id');
      if (rows.isEmpty) {
        throw const AppFailure('Photo could not be saved on your profile.');
      }
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('avatar_path') || message.contains('column')) {
        await staffAvatarLocalStore().save(accountId, path);
        return;
      }
      throw AppFailure.fromPostgrest(error);
    }
  }

  static String _extensionForName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpeg' || 'jpg' || 'png' || 'webp' => ext == 'jpeg' ? 'jpg' : ext,
      _ => 'jpg',
    };
  }

  static String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}