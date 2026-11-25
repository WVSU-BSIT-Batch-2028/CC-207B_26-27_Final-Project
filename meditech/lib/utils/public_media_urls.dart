import 'package:supabase_flutter/supabase_flutter.dart';

const pharmacyDocumentsBucket = 'pharmacy-documents';
const medicineImagesBucket = 'medicine-images';

/// Public medicine pack shot (`medicine-images` bucket).
String? medicineImagePublicUrl(String? path, {int? cacheBust}) {
  if (path == null || path.isEmpty) return null;
  try {
    final base =
        Supabase.instance.client.storage.from(medicineImagesBucket).getPublicUrl(path);
    final bust = cacheBust ?? path.hashCode;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}v=$bust';
  } catch (_) {
    return null;
  }
}

/// Storefront photo in private bucket; guests may read via storage RLS + signed URL,
/// or via public mirror when `branch_documents` RLS blocks unauthenticated subqueries.
Future<String?> pharmacyStorefrontSignedUrl(
  SupabaseClient client,
  String? path, {
  int expiresSeconds = 3600,
}) async {
  if (path == null || path.isEmpty) return null;
  try {
    return await client.storage
        .from(pharmacyDocumentsBucket)
        .createSignedUrl(path, expiresSeconds);
  } catch (_) {
    // Fallback to public mirror in staff-avatars ({branchId}/{userId}/{fileName})
    final parts = path.split('/');
    if (parts.length >= 4 && parts[1] == 'storefront') {
      final branchId = parts[0];
      final userId = parts[2];
      final fileName = parts.sublist(3).join('/');
      return client.storage
          .from('staff-avatars')
          .getPublicUrl('$branchId/$userId/$fileName');
    }
    return null;
  }
}