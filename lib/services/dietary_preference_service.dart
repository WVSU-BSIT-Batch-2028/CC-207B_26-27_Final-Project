import 'package:supabase_flutter/supabase_flutter.dart';

/// User-confirmed preferences, stored separately from the AI's guesses.
/// Only the signed-in student may read or update this row (via Supabase RLS).
class DietaryPreferences {
  const DietaryPreferences({
    this.labels = const <String>{},
    this.alwaysExcludeLabels = const <String>{},
  });

  /// All saved profile labels (likes, patterns, avoidances and safety notes).
  final Set<String> labels;

  /// Selected avoid_* labels that must never be overridden by a search request.
  final Set<String> alwaysExcludeLabels;

  /// Allergies and medically strict restrictions remain active in every search.
  Set<String> get safetyRestrictions => labels
      .where(
        (label) =>
            label.startsWith('allergy_') || label.startsWith('restriction_'),
      )
      .toSet();

  Set<String> get dietaryPatterns =>
      labels.where((label) => label.startsWith('diet_')).toSet();

  /// Avoidances applied by default but overridable for one search.
  Set<String> get flexibleAvoidances => labels
      .where(
        (label) =>
            label.startsWith('avoid_') && !alwaysExcludeLabels.contains(label),
      )
      .toSet();

  Set<String> get likedFoods =>
      labels.where((label) => label.startsWith('pref_')).toSet();

  /// Compatibility getter for older UI code.
  Set<String> get restrictions => {
    ...safetyRestrictions,
    ...dietaryPatterns,
    ...flexibleAvoidances,
    ...alwaysExcludeLabels,
  };
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
        .select('labels, always_exclude_labels')
        .eq('user_id', id)
        .maybeSingle();

    final rawLabels = record?['labels'];
    final labels = rawLabels is List
        ? rawLabels.whereType<String>().where(allowedLabels.contains).toSet()
        : <String>{};

    final rawAlwaysExclude = record?['always_exclude_labels'];
    final alwaysExcludeLabels = rawAlwaysExclude is List
        ? rawAlwaysExclude
              .whereType<String>()
              .where(labels.contains)
              .where((label) => label.startsWith('avoid_'))
              .toSet()
        : <String>{};

    return DietaryPreferences(
      labels: labels,
      alwaysExcludeLabels: alwaysExcludeLabels,
    );
  }

  static Future<DietaryPreferences> save(
    Set<String> selected, {
    Set<String> alwaysExcludeLabels = const <String>{},
  }) async {
    final id = _userId;
    final labels = selected.intersection(allowedLabels);
    if (labels.contains('diet_vegan') && labels.contains('diet_vegetarian')) {
      throw ArgumentError('Choose vegan or vegetarian, not both.');
    }

    // Only a selected "Foods to avoid" item can be marked Always exclude.
    final strictAvoidances = alwaysExcludeLabels
        .intersection(labels)
        .where((label) => label.startsWith('avoid_'))
        .toSet();

    await _db.from('dietary_preferences').upsert({
      'user_id': id,
      'labels': labels.toList()..sort(),
      'always_exclude_labels': strictAvoidances.toList()..sort(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    return DietaryPreferences(
      labels: labels,
      alwaysExcludeLabels: strictAvoidances,
    );
  }
}