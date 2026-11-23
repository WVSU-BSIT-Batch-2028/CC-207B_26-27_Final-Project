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

/// Storefront photo in private bucket; guests may read via storage RLS + signed URL.
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
    return null;
  }
}