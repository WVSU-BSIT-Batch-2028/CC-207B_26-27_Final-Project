import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads `image_path` from `medicines` when RPC rows omit it (older DB functions).
Future<Map<String, String?>> medicineImagePathsById(
  SupabaseClient client,
  Iterable<String> medicineIds,
) async {
  final ids = medicineIds.toSet().where((id) => id.isNotEmpty).toList();
  if (ids.isEmpty) return {};

  final rows = await client.from('medicines').select('id, image_path').inFilter('id', ids);
  return {
    for (final row in rows as List<dynamic>)
      '${(row as Map)['id']}': row['image_path'] as String?,
  };
}