import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_service.dart';
import 'strapi_service.dart';

/// Real published Strapi food item. Allergen fields are seller-reported;
/// an empty list is not proof that an item is safe from cross-contact.
class FoodWiseMeal {
  const FoodWiseMeal({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.business,
    required this.category,
    required this.ingredients,
    required this.containsAllergens,
    required this.mayContainAllergens,
    required this.allergenInfoProvided,
    required this.allergenNotes,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String business;
  final String category;
  final String ingredients;
  final Set<String> containsAllergens;
  final Set<String> mayContainAllergens;
  final bool allergenInfoProvided;
  final String allergenNotes;
  final String? imageUrl;

  static String _asText(dynamic value) => value == null ? '' : '$value';

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) {
      return {};
    }
    final map = Map<String, dynamic>.from(value);
    if (map['data'] is Map) {
      return _asMap(map['data']);
    }
    if (map['attributes'] is Map) {
      return {...map, ..._asMap(map['attributes'])};
    }
    return map;
  }

  static String _relationName(dynamic value) {
    final name = _asText(_asMap(value)['name']).trim();
    return name.isEmpty ? 'Not specified' : name;
  }

  static String? _mediaUrl(dynamic value) {
    if (value is List && value.isNotEmpty) {
      value = value.first;
    }
    final raw = _asText(_asMap(value)['url']).trim();
    if (raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      return raw;
    }
    return Uri.parse(StrapiService.baseUrl).resolve(raw).toString();
  }

  /// Accept JSON string arrays, actual JSON arrays, or null.
  static Set<String> _allergens(dynamic value) {
    if (value == null) {
      return {};
    }
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return {}; // Malformed/unknown data must not imply safety.
      }
    }
    if (value is! List) {
      return {};
    }
    return value
        .whereType<String>()
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static FoodWiseMeal? fromStrapi(Map<String, dynamic> record) {
    final data = _asMap(record);
    if (data['isAvailable'] != true) {
      return null;
    }
    if (data.containsKey('publishedAt') && data['publishedAt'] == null) {
      return null;
    }

    final name = _asText(data['name']).trim();
    final price = double.tryParse(_asText(data['price']));
    if (name.isEmpty || price == null || !price.isFinite || price < 0) {
      return null;
    }

    return FoodWiseMeal(
      id: _asText(data['documentId'] ?? data['id']),
      name: name,
      description: _asText(data['description']).trim(),
      price: price,
      business: _relationName(data['business']),
      category: _relationName(data['category']),
      ingredients: _asText(data['ingredients']).trim(),
      containsAllergens: _allergens(data['containsAllergens']),
      mayContainAllergens: _allergens(data['mayContainAllergens']),
      allergenInfoProvided: data['allergenInfoProvided'] == true,
      allergenNotes: _asText(data['allergenNotes']).trim(),
      imageUrl: _mediaUrl(data['image']),
    );
  }
}

class FoodWiseMealMatch {
  const FoodWiseMealMatch({
    required this.meal,
    required this.score,
    required this.needsIngredientVerification,
    required this.reasons,
    required this.verificationMessage,
  });

  final FoodWiseMeal meal;
  final int score;
  final bool needsIngredientVerification;
  final String verificationMessage;
  final List<String> reasons;
}

class FoodWiseMealService {
  static Future<List<FoodWiseMeal>> fetchAvailableMeals() async {
    final meals = <FoodWiseMeal>[];
    final seen = <String>{};
    // Strapi uses pagination. Published is the public API default.
    for (var page = 1; page <= 20; page++) {
      final url = Uri.parse('${StrapiService.baseUrl}/api/food-items').replace(
        queryParameters: {
          'populate': '*',
          'pagination[page]': '$page',
          'pagination[pageSize]': '100',
          'filters[isAvailable][\$eq]': 'true',
        },
      );
      final response = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(
          'Strapi HTTP ${response.statusCode}: check CMS, public permissions and CORS.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('Unexpected Strapi response format.');
      }
      final records = decoded['data'] as List;
      for (final value in records) {
        if (value is! Map) {
          continue;
        }
        final meal = FoodWiseMeal.fromStrapi(Map<String, dynamic>.from(value));
        if (meal == null) {
          continue;
        }
        final key = meal.id.isNotEmpty
            ? meal.id
            : '${meal.name}|${meal.business}';
        if (seen.add(key)) {
          meals.add(meal);
        }
      }
      final meta = decoded['meta'];
      final paging = meta is Map ? meta['pagination'] : null;
      final pages = paging is Map
          ? (paging['pageCount'] as num?)?.toInt()
          : null;
      if (records.isEmpty ||
          (pages != null ? page >= pages : records.length < 100)) {
        break;
      }
    }
    return meals;
  }

  static double? extractBudget(String request) {
    final patterns = [
      RegExp(r'(?:₱|php\s*)(\d+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(
        r'\b(?:under|below|less than|max(?:imum)?|budget(?: of)?|within|hanggang|up to)\s*(?:₱|php\s*)?(\d+(?:\.\d{1,2})?)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(\d+(?:\.\d{1,2})?)\s*(?:pesos|php)\b', caseSensitive: false),
    ];
    for (final regex in patterns) {
      final match = regex.firstMatch(request);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  // Standardized vocabulary used in Strapi's JSON allergen arrays.
  // NOTE: wheat is not the only source of gluten. Seller confirmation remains essential.
  static const Map<String, Set<String>> _allergenAliases = {
    'milk': {'milk', 'dairy', 'gatas', 'cheese', 'keso', 'butter', 'cream'},
    'egg': {'egg', 'eggs', 'itlog', 'mayonnaise'},
    'peanuts': {'peanuts', 'peanut', 'mani', 'groundnut', 'groundnuts'},
    'fish': {'fish', 'isda', 'bangus', 'tilapia'},
    'shellfish': {'shellfish', 'shrimp', 'hipon', 'prawn', 'crab'},
    'seafood': {'seafood', 'lamang dagat', 'lamang-dagat'},
    'wheat': {'wheat', 'trigo', 'flour'},
    'gluten': {'gluten', 'wheat', 'trigo', 'barley', 'rye'},
    'soy': {'soy', 'soya', 'soybean'},
    'sesame': {'sesame'},
    'tree_nuts': {'tree_nuts', 'tree nuts', 'cashew', 'almond'},
  };

  static Set<String> _standardize(Set<String> raw) {
    final result = <String>{};
    for (final item in raw) {
      final normalized = item.trim().toLowerCase();
      var matched = false;
      for (final entry in _allergenAliases.entries) {
        if (entry.key == normalized || entry.value.contains(normalized)) {
          result.add(entry.key);
          matched = true;
        }
      }
      if (!matched) {
        result.add(normalized);
      }
    }
    return result;
  }

  static bool _hasWord(String text, Iterable<String> terms) {
    for (final term in terms) {
      final expression = RegExp(
        r'\b' + RegExp.escape(term) + r'\b',
        caseSensitive: false,
      );
      if (expression.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// Only explicitly requested/accepted food preferences determine relevance.
  /// A low price or a meal-time category is never enough to make an unrelated
  /// food qualify when the student requests a particular ingredient/food.
  ///
  /// Restrictions are applied even when [restrictionsConfirmed] is false.
  /// Confirmation in the UI acknowledges the user's stated restriction; it
  /// never overrides known ingredient/allergen exclusions.
  static List<FoodWiseMealMatch> rank({
    required List<FoodWiseMeal> meals,
    required FoodWiseAiResult interpretation,
    Set<String> acceptedSuggestions = const {},
    bool restrictionsConfirmed = false,
    Set<String> savedLabels = const <String>{},
    double? budget,
  }) {
    final labels = <String>{
      ...interpretation.detectedLabels,
      ...acceptedSuggestions,
      // Always enforce stored restrictions and dietary patterns.
      ...savedLabels.where((label) => !label.startsWith('pref_')),
    };
    // restrictionsConfirmed is retained for compatibility with the existing
    // screen. Confirmation never disables filtering or safety checks.

    const foodPreferences = <String, List<String>>{
      'pref_chicken': ['chicken', 'manok'],
      'pref_fish': ['fish', 'isda', 'tilapia', 'bangus'],
      'pref_vegetables': [
        'vegetable',
        'vegetables',
        'veggie',
        'veggies',
        'gulay',
        'salad',
      ],
      'pref_rice': [
        'rice',
        'kanin',
        'silog',
        'tapsilog',
        'longsilog',
        'hotsilog',
        'sinangag',
      ],
      'pref_noodles': [
        'noodle',
        'noodles',
        'pancit',
        'ramen',
        'pasta',
        'mami',
        'spaghetti',
      ],
      'pref_egg': ['egg', 'eggs', 'itlog'],
      'pref_fruit': ['fruit', 'fruits', 'prutas', 'banana', 'mango', 'apple'],
    };

    // Meal times are weak ranking signals only. A rice dish is not
    // automatically a lunch item, nor is a noodle dish a dinner item.
    const mealTimes = <String, List<String>>{
      'meal_breakfast': ['breakfast', 'almusal', 'morning'],
      'meal_lunch': ['lunch', 'tanghalian'],
      'meal_dinner': ['dinner', 'hapunan', 'supper'],
      'meal_snack': ['snack', 'merienda', 'meryenda'],
    };

    final requestedFoods = foodPreferences.keys.where(labels.contains).toList();

    // Allergen identifiers in the Strapi JSON fields are canonicalized by
    // _standardize(), but also check seller-reported plain-text ingredients.
    final excludedAllergens = <String>{};
    void exclude(Set<String> allergens) {
      excludedAllergens.addAll(allergens);
    }

    if (labels.contains('avoid_dairy')) {
      exclude({'milk'});
    }
    if (labels.contains('allergy_dairy')) {
      exclude({'milk'});
    }
    if (labels.contains('avoid_egg')) {
      exclude({'egg'});
    }
    if (labels.contains('allergy_egg')) {
      exclude({'egg'});
    }
    if (labels.contains('avoid_peanuts')) {
      exclude({'peanuts'});
    }
    if (labels.contains('allergy_peanuts')) {
      exclude({'peanuts'});
    }
    if (labels.contains('avoid_seafood')) {
      exclude({'fish', 'shellfish', 'seafood'});
    }
    if (labels.contains('allergy_seafood')) {
      exclude({'fish', 'shellfish', 'seafood'});
    }
    if (labels.contains('avoid_gluten')) {
      exclude({'gluten', 'wheat'});
    }
    if (labels.contains('restriction_gluten') ||
        labels.contains('allergy_gluten')) {
      exclude({'gluten', 'wheat'});
    }
    if (labels.contains('diet_vegetarian') || labels.contains('diet_vegan')) {
      exclude({'fish', 'shellfish', 'seafood'});
    }
    if (labels.contains('diet_vegan')) {
      exclude({'milk', 'egg'});
    }

    final textExclusions = <String>{};
    for (final allergen in excludedAllergens) {
      textExclusions.addAll(_allergenAliases[allergen] ?? {allergen});
    }
    if (labels.contains('avoid_spicy')) {
      textExclusions.addAll({
        'spicy',
        'maanghang',
        'chili',
        'chilli',
        'hot sauce',
      });
    }
    if (labels.contains('diet_vegetarian') || labels.contains('diet_vegan')) {
      textExclusions.addAll({
        'chicken',
        'manok',
        'beef',
        'pork',
        'baboy',
        'meat',
        'fish',
        'isda',
        'shrimp',
        'hipon',
        'seafood',
        'shellfish',
        'bacon',
        'ham',
        'gelatin',
        'patis',
        'fish sauce',
      });
    }
    if (labels.contains('diet_vegan')) {
      textExclusions.addAll({'honey', 'egg', 'eggs', 'milk', 'cheese'});
    }

    final restrictions = labels.any(
      (label) =>
          label.startsWith('avoid_') ||
          label.startsWith('allergy_') ||
          label.startsWith('restriction_') ||
          label.startsWith('diet_'),
    );

    final ranked = <FoodWiseMealMatch>[];
    for (final meal in meals) {
      // Price limits are filters, not recommendation scores.
      if (budget != null && meal.price > budget) {
        continue;
      }

      final contains = _standardize(meal.containsAllergens);
      final mayContain = _standardize(meal.mayContainAllergens);
      final listingText = '${meal.name} ${meal.description} ${meal.category}'
          .toLowerCase();
      final combinedText = '$listingText ${meal.ingredients}'.toLowerCase();

      // Apply known safety conflicts BEFORE considering any ranking signals.
      if (contains.intersection(excludedAllergens).isNotEmpty) {
        continue;
      }
      if (_hasWord(combinedText, textExclusions)) {
        continue;
      }
      // Exclude declared cross-contact conflicts for any requested exclusion
      // (including vegetarian/vegan patterns). Unknown data remains unverified.
      if (mayContain.intersection(excludedAllergens).isNotEmpty) {
        continue;
      }

      final matchedFoods = <String>[];
      for (final label in requestedFoods) {
        if (_hasWord(combinedText, foodPreferences[label]!)) {
          matchedFoods.add(label);
        }
      }

      // Require EVERY requested food, not just an affordable price or a
      // generic category. E.g. chicken + rice does not return peanut noodles.
      if (requestedFoods.isNotEmpty &&
          matchedFoods.length != requestedFoods.length) {
        continue;
      }

      var score = matchedFoods.length * 10;
      // Saved favorite foods only affect ordering. They are NOT mandatory
      // matches and never override a student's current explicit request.
      for (final label in savedLabels.where((x) => x.startsWith('pref_'))) {
        final terms = foodPreferences[label];
        if (terms != null && _hasWord(combinedText, terms)) {
          score += 1;
        }
      }
      final reasons = <String>[
        for (final label in matchedFoods)
          'Matches ${label.substring('pref_'.length)} request',
      ];

      for (final entry in mealTimes.entries) {
        if (labels.contains(entry.key) && _hasWord(listingText, entry.value)) {
          score += 2;
          reasons.add('Listed for requested meal time');
          break;
        }
      }
      if (labels.contains('budget_friendly')) {
        if (meal.price <= 100) {
          score += 2;
          reasons.add('Budget-friendly price');
        } else if (meal.price <= 150) {
          score += 1;
        }
      }
      if (budget != null) {
        reasons.add('Within ₱${budget.toStringAsFixed(0)} budget');
      }

      // Seller-supplied fields are NOT independently verified. Incomplete
      // information, a reported restriction or cross-contact always triggers
      // verification messaging instead of an allergy-safe certification.
      final infoComplete =
          meal.allergenInfoProvided && meal.ingredients.isNotEmpty;
      final needsVerification =
          restrictions || !infoComplete || mayContain.isNotEmpty;
      final verificationMessage = !infoComplete
          ? 'Ingredient/allergen information is missing or incomplete. '
                'Ask the seller before relying on this listing.'
          : mayContain.isNotEmpty
          ? 'Seller reports possible cross-contact: '
                '${mayContain.join(', ')}. Verify with the seller.'
          : restrictions
          ? 'Seller-reported details do not guarantee dietary or '
                'allergy suitability. Confirm all ingredients and '
                'cross-contact with the seller.'
          : '';

      ranked.add(
        FoodWiseMealMatch(
          meal: meal,
          score: score,
          reasons: reasons,
          needsIngredientVerification: needsVerification,
          verificationMessage: verificationMessage,
        ),
      );
    }

    // Exact food matches outrank meal-time and affordability tie-breakers.
    // The remaining ties are shown cheapest first, then alphabetically.
    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      final priceOrder = a.meal.price.compareTo(b.meal.price);
      if (priceOrder != 0) {
        return priceOrder;
      }
      return a.meal.name.compareTo(b.meal.name);
    });
    return ranked;
  }
}
