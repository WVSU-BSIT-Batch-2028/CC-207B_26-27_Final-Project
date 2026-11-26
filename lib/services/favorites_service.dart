import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores only stable Strapi food identifiers, scoped to the signed-in user.
class FavoritesService {
  final SupabaseClient _client = Supabase.instance.client;
  final String? _userId;

  FavoritesService() : _userId = Supabase.instance.client.auth.currentUser?.id;

  String _requireUser() {
    final id = _userId;
    if (id == null || _client.auth.currentUser?.id != id) {
      throw StateError('No matching authenticated session.');
    }
    return id;
  }

  Future<Set<String>> fetchFavorites() async {
    final id = _requireUser();
    final keys = <String>{};
    // Page results to avoid Supabase's default maximum response size.
    const pageSize = 200;
    for (var offset = 0; ; offset += pageSize) {
      _requireUser();
      final rows = await _client
          .from('favorites')
          .select('food_document_id')
          .eq('user_id', id)
          .order('food_document_id')
          .range(offset, offset + pageSize - 1);
      keys.addAll(rows.map((row) => row['food_document_id'] as String));
      if (rows.length < pageSize) break;
    }
    _requireUser();
    return keys;
  }

  Future<void> setFavorite(String foodKey, bool saved) async {
    final id = _requireUser();
    if (foodKey.trim().isEmpty) {
      throw ArgumentError('Missing Strapi document ID.');
    }
    if (saved) {
      // Ignore duplicates rather than updating an existing row.
      await _client
          .from('favorites')
          .upsert(
            {'user_id': id, 'food_document_id': foodKey},
            onConflict: 'user_id,food_document_id',
            ignoreDuplicates: true,
          );
    } else {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', id)
          .eq('food_document_id', foodKey);
    }
  }
}
