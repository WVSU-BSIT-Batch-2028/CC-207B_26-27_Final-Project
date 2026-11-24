import 'package:supabase_flutter/supabase_flutter.dart';

/// User-confirmed preferences, stored separately from the AI's guesses.
/// Only the signed-in student may read or update this row (via Supabase RLS).
class DietaryPreferences {
  const DietaryPreferences({this.labels = const <String>{}});

  final Set<String> labels;

  Set<String> get restrictions => labels
      .where(
        (label) =>
            label.startsWith('avoid_') ||
            label.startsWith('allergy_') ||
            label.startsWith('restriction_') ||
            label.startsWith('diet_'),
      )
      .toSet();

  Set<String> get likedFoods =>
      labels.where((label) => label.startsWith('pref_')).toSet();
}

class DietaryPreferenceService {
  static const Set<String> allowedLabels = {
    'pref_chicken',
    'pref_fish',
    'pref_vegetables',
    'pref_rice',
    'pref_noodles',
    'pref_egg',
    'pref_fruit',
    'diet_vegetarian',
    'diet_vegan',
    'avoid_spicy',
    'avoid_dairy',
    'avoid_peanuts',
    'avoid_seafood',
    'avoid_egg',
    'avoid_gluten',
    'allergy_peanuts',
    'allergy_dairy',
    'allergy_seafood',
    'allergy_egg',
    'allergy_gluten',
    'restriction_gluten',
  };

  static SupabaseClient get _db => Supabase.instance.client;

  static String get _userId {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to manage dietary preferences.');
    }
    return user.id;
  }

  static Future<DietaryPreferences> load() async {
    final id = _userId;
    final record = await _db
        .from('dietary_preferences')
        .select('labels')
        .eq('user_id', id)
        .maybeSingle();
    final raw = record?['labels'];
    final labels = raw is List
        ? raw.whereType<String>().where(allowedLabels.contains).toSet()
        : <String>{};
    return DietaryPreferences(labels: labels);
  }

  static Future<DietaryPreferences> save(Set<String> selected) async {
    final id = _userId;
    final labels = selected.intersection(allowedLabels);
    if (labels.contains('diet_vegan') && labels.contains('diet_vegetarian')) {
      throw ArgumentError('Choose vegan or vegetarian, not both.');
    }
    await _db.from('dietary_preferences').upsert({
      'user_id': id,
      'labels': labels.toList()..sort(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    return DietaryPreferences(labels: labels);
  }
}
