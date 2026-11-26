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
    this.allergenDataValid = true,
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
  final bool allergenDataValid;
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

  /// Returns true only when Strapi supplied a parseable allergen array.
  /// Null or malformed data must not be treated as a verified empty list.
  static bool _isValidAllergenArray(dynamic value) {
    if (value is List) {
      return value.every((item) => item is String);
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return decoded is List && decoded.every((item) => item is String);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Parse JSON string arrays or actual JSON arrays. Validation is tracked
  /// separately so malformed or partially invalid data prompts verification.
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
      allergenDataValid:
          _isValidAllergenArray(data['containsAllergens']) &&
          _isValidAllergenArray(data['mayContainAllergens']),
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
    const pageSize = 100;
    // Avoid silently returning a partial catalog if pagination is misconfigured
    // or the catalog grows unexpectedly large.
    const maxPages = 100;

    final meals = <FoodWiseMeal>[];
    final seen = <String>{};

    // Strapi's public API returns published entries by default.
    for (var page = 1; page <= maxPages; page++) {
      final url = Uri.parse('${StrapiService.baseUrl}/api/food-items').replace(
        queryParameters: {
          'populate': '*',
          'pagination[page]': '$page',
          'pagination[pageSize]': '$pageSize',
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
      final hasMorePages =
          records.isNotEmpty &&
          (pages != null ? page < pages : records.length == pageSize);

      if (!hasMorePages) {
        break;
      }
      if (page == maxPages) {
        throw StateError(
          'The meal catalog exceeds the supported pagination limit. '
          'Increase maxPages or review the Strapi pagination response.',
        );
      }
    }

    return meals;
  }

  static double? extractBudget(String request) {
    // Supports comma-separated amounts such as 1,000 and decimal amounts.
    const amount = r'((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)';
    final patterns = [
      RegExp('(?:₱|php\\s*)$amount', caseSensitive: false),
      RegExp(
        '\\b(?:under|below|less than|max(?:imum)?|budget(?: of)?|within|hanggang|up to)\\s*(?:₱|php\\s*)?$amount\\b',
        caseSensitive: false,
      ),
      RegExp('\\b$amount\\s*(?:pesos|php)\\b', caseSensitive: false),
    ];
    for (final regex in patterns) {
      final match = regex.firstMatch(request);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  // Standardized vocabulary used in Strapi's JSON allergen arrays.
  // NOTE: wheat is not the only source of gluten. Seller confirmation remains essential.
  static const Map<String, Set<String>> _allergenAliases = {
    'milk': {
      'milk',
      'dairy',
      'gatas',
      'cheese',
      'keso',
      'butter',
      'cream',
      'yogurt',
      'yoghurt',
      'buttermilk',
      'ghee',
      'whey',
      'casein',
      'lactose',
      'milk powder',
      'milk solids',
      'condensed milk',
      'evaporated milk',
      'cream cheese',
    },
    'egg': {
      'egg',
      'eggs',
      'itlog',
      'mayonnaise',
      'mayo',
      'albumin',
      'egg white',
      'egg yolk',
      'egg powder',
    },
    'peanuts': {'peanuts', 'peanut', 'mani', 'groundnut', 'groundnuts'},
    'fish': {
      'fish',
      'isda',
      'bangus',
      'tilapia',
      'salmon',
      'tuna',
      'sardine',
      'sardines',
      'anchovy',
      'anchovies',
      'mackerel',
      'cod',
      'fish sauce',
    },
    'shellfish': {
      'shellfish',
      'shrimp',
      'hipon',
      'prawn',
      'crab',
      'lobster',
      'oyster',
      'mussel',
      'clam',
      'scallop',
      'shrimp paste',
      'oyster sauce',
    },
    'seafood': {'seafood', 'lamang dagat', 'lamang-dagat'},
    'wheat': {
      'wheat',
      'trigo',
      'flour',
      'semolina',
      'durum',
      'bulgur',
      'couscous',
    },
    'gluten': {
      'gluten',
      'wheat',
      'trigo',
      'barley',
      'rye',
      'triticale',
      'malt',
      'seitan',
    },
    'soy': {
      'soy',
      'soya',
      'soybean',
      'soy sauce',
      'tofu',
      'tempeh',
      'edamame',
      'miso',
    },
    'sesame': {'sesame', 'sesame seed', 'sesame oil', 'tahini'},
    'tree_nuts': {
      'tree_nuts',
      'tree nuts',
      'cashew',
      'almond',
      'walnut',
      'pecan',
      'pistachio',
      'hazelnut',
      'macadamia',
      'brazil nut',
      'pine nut',
    },
  };

  static const Set<String> _dairyTextTerms = {
    'dairy',
    'milk',
    'gatas',
    'cheese',
    'keso',
    'butter',
    'cream',
    'yogurt',
    'yoghurt',
    'buttermilk',
    'ghee',
    'whey',
    'casein',
    'lactose',
    'milk powder',
    'milk solids',
    'condensed milk',
    'evaporated milk',
    'cream cheese',
  };

  // These terms describe ingredients that are animal-derived in common food
  // use. Specific broth/stock terms are used instead of the broad word "broth"
  // so vegetable broth is not incorrectly rejected.
  // Some ingredients can be plant- or animal-derived depending on the
  // supplier or manufacturing process. These trigger seller verification,
  // rather than automatic rejection, for vegan requests.
  static const Set<String> _ambiguousVeganTerms = {
    'margarine',
    'natural flavor',
    'natural flavors',
    'natural flavour',
    'natural flavours',
    'mono and diglycerides',
    'mono- and diglycerides',
    'diglycerides',
    'vitamin d3',
    'rennet',
    'enzyme',
    'enzymes',
  };

  static const Set<String> _animalDerivedTerms = {
    'chicken',
    'manok',
    'beef',
    'pork',
    'baboy',
    'lamb',
    'mutton',
    'goat',
    'duck',
    'turkey',
    'venison',
    'meat',
    'fish',
    'isda',
    'bangus',
    'tilapia',
    'salmon',
    'tuna',
    'sardine',
    'anchovy',
    'shrimp',
    'hipon',
    'prawn',
    'crab',
    'lobster',
    'oyster',
    'mussel',
    'clam',
    'scallop',
    'squid',
    'octopus',
    'seafood',
    'shellfish',
    'bacon',
    'ham',
    'sausage',
    'hotdog',
    'hot dog',
    'gelatin',
    'collagen',
    'lard',
    'tallow',
    'suet',
    'patis',
    'fish sauce',
    'oyster sauce',
    'shrimp paste',
    'bagoong',
    'alamang',
    'dried shrimp',
    'fish flakes',
    'bonito',
    'worcestershire sauce',
    'chicken broth',
    'beef broth',
    'pork broth',
    'fish broth',
    'bone broth',
    'chicken stock',
    'beef stock',
    'pork stock',
    'fish stock',
    'meat stock',
    'seafood stock',
    'animal stock',
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

  /// Removes clearly plant-based substitutes before checking dairy terms.
  /// This prevents coconut/oat milk, vegan cheese, and peanut butter from
  /// being mistaken for animal-derived dairy ingredients.
  static String _removePlantBasedDairyAlternatives(String text) {
    var cleaned = text;
    const patterns = [
      r'\b(?:oat|soy|soya|almond|coconut|rice|cashew|hazelnut|hemp|pea|flax|vegan|plant[- ]based|non[- ]dairy|dairy[- ]free|soy[- ]based|(?:oat|soy|soya|almond|coconut|rice|cashew|hazelnut|hemp|pea|flax)[- ]based)\s+(?:milk|cream|yogurt|yoghurt)\b',
      r'\b(?:vegan|plant[- ]based|dairy[- ]free|soy[- ]based|nut|cashew|almond|macadamia)\s+(?:cream\s+)?cheese\b',
      r'\b(?:peanut|almond|cashew|sunflower|cocoa|shea|vegan|plant[- ]based|apple|pumpkin|cookie|nut|seed|soy)\s+butter\b',
      r'\b(?:cream of tartar|cream of coconut|non[- ]dairy creamer|dairy[- ]free|milk[- ]free|cheese[- ]free|butter[- ]free|cream[- ]free|yogurt[- ]free|yoghurt[- ]free|butter beans?)\b',
    ];
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), ' ');
    }
    return cleaned;
  }

  static bool _hasDairyIngredient(String text) {
    final searchableText = _removePlantBasedDairyAlternatives(text);
    return _hasWord(searchableText, _dairyTextTerms);
  }

  /// Removes clearly plant-based animal-product substitutes while leaving
  /// other ingredients in the text available for restriction checks.
  static String _removePlantBasedAnimalAlternatives(String text) {
    var cleaned = text.replaceAll(
      RegExp(
        r'\b(?:vegan|vegetarian|plant[- ]based|meatless|veggie)\s+(?:chicken|beef|pork|lamb|turkey|duck|fish|shrimp|prawn|crab|bacon|ham|sausage|hot[ -]?dog|meat)\b|\bmeat[- ]free(?:\s+(?:chicken|beef|pork|fish|bacon|ham|sausage|burger))?\b|\bmeat\s+(?:substitute|alternative)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:vegan|plant[- ]based|egg[- ]free)\s+(?:mayonnaise|mayo|egg|eggs)\b|\b(?:egg replacer|egg replacement|egg substitute)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    return cleaned;
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
    Set<String> savedAlwaysExcludeLabels = const <String>{},
    double? budget,
  }) {
    final normalizedSavedLabels = savedLabels
        .map((label) => label.trim().toLowerCase())
        .where((label) => label.isNotEmpty)
        .toSet();
    final normalizedAlwaysExclude = savedAlwaysExcludeLabels
        .map((label) => label.trim().toLowerCase())
        .where(
          (label) =>
              label.startsWith('avoid_') &&
              normalizedSavedLabels.contains(label),
        )
        .toSet();

    final explicitLabels = <String>{
      ...interpretation.detectedLabels
          .map((label) => label.trim().toLowerCase())
          .where((label) => label.isNotEmpty),
      ...acceptedSuggestions
          .map((label) => label.trim().toLowerCase())
          .where((label) => label.isNotEmpty),
    };
    final explicitlyExcludedFoods = interpretation.excludedFoods
        .map((food) => food.trim().toLowerCase())
        .where((food) => food.isNotEmpty)
        .toSet();
    final requestedFoods = <String>{
      ...interpretation.requestedFoods,
      if (explicitLabels.contains('pref_chicken')) 'chicken',
      if (explicitLabels.contains('pref_fish')) 'fish',
      if (explicitLabels.contains('pref_vegetables')) 'vegetables',
      if (explicitLabels.contains('pref_rice')) 'rice',
      if (explicitLabels.contains('pref_noodles')) 'noodles',
      if (explicitLabels.contains('pref_egg')) 'egg',
      if (explicitLabels.contains('pref_fruit')) 'fruit',
    }..removeAll(explicitlyExcludedFoods);

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
    const preferenceToFood = <String, String>{
      'pref_chicken': 'chicken',
      'pref_fish': 'fish',
      'pref_vegetables': 'vegetables',
      'pref_rice': 'rice',
      'pref_noodles': 'noodles',
      'pref_egg': 'egg',
      'pref_fruit': 'fruit',
    };
    const requestedFoodTerms = <String, List<String>>{
      'chicken': ['chicken', 'manok'],
      'fish': [
        'fish',
        'isda',
        'bangus',
        'tilapia',
        'salmon',
        'tuna',
        'sardine',
        'sardines',
      ],
      'vegetables': [
        'vegetable',
        'vegetables',
        'veggie',
        'veggies',
        'gulay',
        'carrot',
        'tomato',
        'cabbage',
        'lettuce',
        'broccoli',
      ],
      'rice': ['rice', 'kanin', 'sinangag', 'fried rice', 'garlic rice'],
      'noodles': [
        'noodle',
        'noodles',
        'pancit',
        'ramen',
        'pasta',
        'mami',
        'spaghetti',
        'sotanghon',
        'bihon',
      ],
      'egg': ['egg', 'eggs', 'itlog', 'mayonnaise'],
      'fruit': [
        'fruit',
        'fruits',
        'prutas',
        'banana',
        'mango',
        'apple',
        'orange',
        'pineapple',
        'papaya',
      ],
      'spicy': [
        'spicy',
        'maanghang',
        'chili',
        'chilli',
        'hot sauce',
        'sriracha',
      ],
      'dairy': [
        'dairy',
        'milk',
        'gatas',
        'cheese',
        'keso',
        'butter',
        'cream',
        'yogurt',
        'yoghurt',
      ],
      'peanuts': ['peanut', 'peanuts', 'mani', 'groundnut', 'peanut butter'],
      'seafood': [
        'seafood',
        'shrimp',
        'hipon',
        'prawn',
        'crab',
        'lobster',
        'oyster',
        'mussel',
        'clam',
        'squid',
        'octopus',
        'lamang dagat',
      ],
      'gluten': ['gluten', 'wheat', 'trigo', 'barley', 'rye', 'bread', 'flour'],
      'shellfish': [
        'shellfish',
        'shrimp',
        'hipon',
        'prawn',
        'crab',
        'lobster',
        'oyster',
        'mussel',
        'clam',
        'scallop',
        'shrimp paste',
        'oyster sauce',
      ],
      'soy': ['soy', 'soya', 'soybean', 'soy sauce', 'tofu', 'tempeh', 'miso'],
      'sesame': ['sesame', 'sesame seed', 'sesame oil', 'tahini'],
      'tree_nuts': [
        'tree nuts',
        'cashew',
        'almond',
        'walnut',
        'pecan',
        'pistachio',
        'hazelnut',
        'macadamia',
        'brazil nut',
        'pine nut',
      ],
      'wheat': [
        'wheat',
        'trigo',
        'flour',
        'semolina',
        'durum',
        'bulgur',
        'couscous',
      ],
    };

    // A direct positive request may override a saved eating pattern for this
    // search. A current explicit pattern takes precedence over the saved one.
    final currentPatterns = explicitLabels
        .where((label) => label == 'diet_vegan' || label == 'diet_vegetarian')
        .toSet();
    final effectivePatterns = currentPatterns.isNotEmpty
        ? <String>{...currentPatterns}
        : normalizedSavedLabels
              .where(
                (label) => label == 'diet_vegan' || label == 'diet_vegetarian',
              )
              .toSet();

    final hasAnimalFoodRequest = requestedFoods.any(
      {'chicken', 'fish', 'seafood'}.contains,
    );
    final hasVeganConflictRequest = requestedFoods.any(
      {'egg', 'dairy'}.contains,
    );
    if (currentPatterns.isEmpty) {
      if (effectivePatterns.contains('diet_vegetarian') &&
          hasAnimalFoodRequest) {
        effectivePatterns.remove('diet_vegetarian');
      }
      if (effectivePatterns.contains('diet_vegan') &&
          (hasAnimalFoodRequest || hasVeganConflictRequest)) {
        effectivePatterns.remove('diet_vegan');
      }
    }

    const avoidLabelToFood = <String, String>{
      'avoid_spicy': 'spicy',
      'avoid_dairy': 'dairy',
      'avoid_peanuts': 'peanuts',
      'avoid_seafood': 'seafood',
      'avoid_egg': 'egg',
      'avoid_gluten': 'gluten',
      'avoid_fish': 'fish',
      'avoid_shellfish': 'shellfish',
      'avoid_soy': 'soy',
      'avoid_sesame': 'sesame',
      'avoid_tree_nuts': 'tree_nuts',
      'avoid_wheat': 'wheat',
    };
    final savedFlexibleAvoidances = normalizedSavedLabels
        .where(
          (label) =>
              label.startsWith('avoid_') &&
              !normalizedAlwaysExclude.contains(label),
        )
        .toSet();
    final activeSavedFlexibleAvoidances = savedFlexibleAvoidances.where((
      label,
    ) {
      final food = avoidLabelToFood[label];
      final explicitlyRequested = food != null && requestedFoods.contains(food);
      final fishRequestedInsteadOfSeafood =
          label == 'avoid_seafood' && requestedFoods.contains('fish');
      return !explicitlyRequested && !fishRequestedInsteadOfSeafood;
    }).toSet();

    // Allergies and medically strict restrictions always remain active.
    final safetyLabels = <String>{
      ...normalizedSavedLabels.where(
        (label) =>
            label.startsWith('allergy_') || label.startsWith('restriction_'),
      ),
      ...explicitLabels.where(
        (label) =>
            label.startsWith('allergy_') || label.startsWith('restriction_'),
      ),
    };
    final activeAvoidLabels = <String>{
      ...normalizedAlwaysExclude,
      ...activeSavedFlexibleAvoidances,
      ...explicitLabels.where((label) => label.startsWith('avoid_')),
    };

    // Never silently replace a requested food that conflicts with an
    // allergy or a user-marked Always exclude rule with an unrelated meal.
    const safetyLabelToFood = <String, String>{
      'allergy_peanuts': 'peanuts',
      'allergy_dairy': 'dairy',
      'allergy_seafood': 'seafood',
      'allergy_egg': 'egg',
      'allergy_gluten': 'gluten',
      'restriction_gluten': 'gluten',
      'allergy_fish': 'fish',
      'allergy_shellfish': 'shellfish',
      'allergy_soy': 'soy',
      'allergy_sesame': 'sesame',
      'allergy_tree_nuts': 'tree_nuts',
      'allergy_wheat': 'wheat',
    };
    final nonOverrideableFoods = <String>{
      for (final label in safetyLabels)
        if (safetyLabelToFood[label] != null) safetyLabelToFood[label]!,
      for (final label in normalizedAlwaysExclude)
        if (avoidLabelToFood[label] != null) avoidLabelToFood[label]!,
    };
    if (safetyLabels.contains('allergy_seafood') ||
        normalizedAlwaysExclude.contains('avoid_seafood')) {
      nonOverrideableFoods.addAll({'fish', 'seafood'});
    }
    if (requestedFoods.intersection(nonOverrideableFoods).isNotEmpty) {
      return const <FoodWiseMealMatch>[];
    }

    const mealTimes = <String, List<String>>{
      'meal_breakfast': ['breakfast', 'almusal', 'morning'],
      'meal_lunch': ['lunch', 'tanghalian'],
      'meal_dinner': ['dinner', 'hapunan', 'supper'],
      'meal_snack': ['snack', 'merienda', 'meryenda'],
    };
    final rankingLabels = <String>{...explicitLabels, ...effectivePatterns};

    final excludedAllergens = <String>{};
    void exclude(Set<String> allergens) {
      excludedAllergens.addAll(allergens);
    }

    final allAvoidLabels = <String>{...activeAvoidLabels, ...safetyLabels};
    if (allAvoidLabels.contains('avoid_dairy') ||
        allAvoidLabels.contains('allergy_dairy')) {
      exclude({'milk'});
    }
    if (allAvoidLabels.contains('avoid_egg') ||
        allAvoidLabels.contains('allergy_egg')) {
      exclude({'egg'});
    }
    if (allAvoidLabels.contains('avoid_peanuts') ||
        allAvoidLabels.contains('allergy_peanuts')) {
      exclude({'peanuts'});
    }
    if (allAvoidLabels.contains('avoid_seafood') ||
        allAvoidLabels.contains('allergy_seafood')) {
      exclude({'fish', 'shellfish', 'seafood'});
    }
    if (allAvoidLabels.contains('avoid_gluten') ||
        allAvoidLabels.contains('allergy_gluten') ||
        allAvoidLabels.contains('restriction_gluten')) {
      exclude({'gluten', 'wheat'});
    }
    if (allAvoidLabels.contains('avoid_fish') ||
        allAvoidLabels.contains('allergy_fish')) {
      exclude({'fish'});
    }
    if (allAvoidLabels.contains('avoid_shellfish') ||
        allAvoidLabels.contains('allergy_shellfish')) {
      exclude({'shellfish'});
    }
    if (allAvoidLabels.contains('avoid_soy') ||
        allAvoidLabels.contains('allergy_soy')) {
      exclude({'soy'});
    }
    if (allAvoidLabels.contains('avoid_sesame') ||
        allAvoidLabels.contains('allergy_sesame')) {
      exclude({'sesame'});
    }
    if (allAvoidLabels.contains('avoid_tree_nuts') ||
        allAvoidLabels.contains('allergy_tree_nuts')) {
      exclude({'tree_nuts'});
    }
    if (allAvoidLabels.contains('avoid_wheat') ||
        allAvoidLabels.contains('allergy_wheat')) {
      exclude({'wheat'});
    }

    // Explicit exclusions apply to this search only.
    for (final food in explicitlyExcludedFoods) {
      switch (food) {
        case 'dairy':
          exclude({'milk'});
          break;
        case 'egg':
          exclude({'egg'});
          break;
        case 'peanuts':
          exclude({'peanuts'});
          break;
        case 'fish':
          exclude({'fish'});
          break;
        case 'seafood':
          exclude({'fish', 'shellfish', 'seafood'});
          break;
        case 'gluten':
          exclude({'gluten', 'wheat'});
          break;
      }
    }

    if (effectivePatterns.contains('diet_vegetarian') ||
        effectivePatterns.contains('diet_vegan')) {
      exclude({'fish', 'shellfish', 'seafood'});
    }
    if (effectivePatterns.contains('diet_vegan')) {
      exclude({'milk', 'egg'});
    }

    final textExclusions = <String>{};
    for (final allergen in excludedAllergens) {
      // Dairy is checked separately so plant-based alternatives such as oat
      // milk and vegan cheese are not mistaken for animal-derived dairy.
      if (allergen == 'milk') {
        continue;
      }
      textExclusions.addAll(_allergenAliases[allergen] ?? {allergen});
    }
    if (allAvoidLabels.contains('avoid_spicy')) {
      textExclusions.addAll({
        'spicy',
        'maanghang',
        'chili',
        'chilli',
        'hot sauce',
        'sriracha',
      });
    }
    if (effectivePatterns.contains('diet_vegetarian') ||
        effectivePatterns.contains('diet_vegan')) {
      textExclusions.addAll(_animalDerivedTerms);
    }
    if (effectivePatterns.contains('diet_vegan')) {
      textExclusions.addAll({
        'honey',
        'bee pollen',
        'royal jelly',
        'propolis',
        'beeswax',
        'carmine',
        'cochineal',
        'shellac',
        'isinglass',
        'animal rennet',
      });
    }

    const directFoodExclusionTerms = <String, Set<String>>{
      'chicken': {'chicken', 'manok'},
      'fish': {
        'fish',
        'isda',
        'bangus',
        'tilapia',
        'salmon',
        'tuna',
        'sardine',
        'sardines',
        'anchovy',
        'anchovies',
        'mackerel',
        'cod',
      },
      'vegetables': {
        'vegetable',
        'vegetables',
        'veggie',
        'veggies',
        'gulay',
        'salad',
        'carrot',
        'carrots',
        'tomato',
        'tomatoes',
        'potato',
        'potatoes',
        'cabbage',
        'lettuce',
        'broccoli',
        'spinach',
        'pechay',
        'kangkong',
        'eggplant',
        'talong',
        'okra',
        'squash',
        'kalabasa',
        'sitaw',
        'ampalaya',
      },
      'rice': {
        'rice',
        'kanin',
        'sinangag',
        'fried rice',
        'garlic rice',
        'silog',
        'tapsilog',
        'longsilog',
        'hotsilog',
      },
      'noodles': {
        'noodle',
        'noodles',
        'pancit',
        'ramen',
        'pasta',
        'mami',
        'spaghetti',
        'sotanghon',
        'bihon',
        'misua',
        'udon',
        'soba',
        'macaroni',
      },
      'egg': {
        'egg',
        'eggs',
        'itlog',
        'mayonnaise',
        'mayo',
        'albumin',
        'egg white',
        'egg yolk',
        'egg powder',
      },
      'fruit': {
        'fruit',
        'fruits',
        'prutas',
        'banana',
        'mango',
        'apple',
        'orange',
        'pineapple',
        'papaya',
        'watermelon',
        'melon',
        'grape',
        'grapes',
        'strawberry',
        'avocado',
      },
      'spicy': {
        'spicy',
        'maanghang',
        'chili',
        'chilli',
        'hot sauce',
        'sriracha',
        'cayenne',
        'jalapeno',
        'siling labuyo',
        'siling haba',
      },
      'dairy': {
        'dairy',
        'milk',
        'gatas',
        'cheese',
        'keso',
        'butter',
        'cream',
        'yogurt',
        'yoghurt',
        'whey',
        'casein',
        'lactose',
        'buttermilk',
        'ghee',
      },
      'peanuts': {
        'peanut',
        'peanuts',
        'mani',
        'groundnut',
        'groundnuts',
        'peanut butter',
        'peanut sauce',
      },
      'seafood': {
        'seafood',
        'lamang dagat',
        'shellfish',
        'fish',
        'isda',
        'shrimp',
        'hipon',
        'prawn',
        'crab',
        'lobster',
        'oyster',
        'mussel',
        'clam',
        'scallop',
        'squid',
        'octopus',
        'patis',
        'fish sauce',
        'shrimp paste',
        'bagoong',
        'alamang',
        'oyster sauce',
      },
      'gluten': {
        'gluten',
        'wheat',
        'trigo',
        'barley',
        'rye',
        'triticale',
        'malt',
        'seitan',
        'flour',
        'semolina',
        'durum',
        'bulgur',
        'couscous',
        'bread',
      },
    };

    for (final food in explicitlyExcludedFoods) {
      // Dairy is handled by _hasDairyIngredient below to avoid false matches
      // on clearly plant-based milk, cream, yogurt, cheese, and butter.
      if (food == 'dairy') {
        continue;
      }
      textExclusions.addAll(directFoodExclusionTerms[food] ?? {food});
    }
    for (final label in normalizedAlwaysExclude) {
      final food = avoidLabelToFood[label];
      if (food != null && food != 'dairy') {
        textExclusions.addAll(directFoodExclusionTerms[food] ?? {food});
      }
    }

    final safetyRestrictionsActive = safetyLabels.isNotEmpty;
    final ranked = <FoodWiseMealMatch>[];

    for (final meal in meals) {
      if (budget != null && meal.price > budget) continue;

      final contains = _standardize(meal.containsAllergens);
      final mayContain = _standardize(meal.mayContainAllergens);
      final listingText = '${meal.name} ${meal.description} ${meal.category}'
          .toLowerCase();
      final combinedText =
          '$listingText ${meal.ingredients} ${meal.allergenNotes}'
              .toLowerCase();
      final restrictionCheckText = _removePlantBasedAnimalAlternatives(
        combinedText,
      );

      if (contains.intersection(excludedAllergens).isNotEmpty) continue;
      if (mayContain.intersection(excludedAllergens).isNotEmpty) continue;

      // Use the dairy-specific checker so clearly plant-based alternatives
      // are not rejected, while actual dairy ingredients remain excluded.
      if (excludedAllergens.contains('milk') &&
          _hasDairyIngredient(combinedText)) {
        continue;
      }

      if (_hasWord(restrictionCheckText, textExclusions)) continue;

      final matchedRequestedFoods = <String>{};
      for (final food in requestedFoods) {
        final terms = requestedFoodTerms[food];
        if (terms != null && _hasWord(combinedText, terms)) {
          matchedRequestedFoods.add(food);
        }
      }

      // Every positively requested food must be present in the listing.
      if (matchedRequestedFoods.length != requestedFoods.length) {
        continue;
      }

      final matchedPreferenceLabels = <String>[
        for (final entry in preferenceToFood.entries)
          if (matchedRequestedFoods.contains(entry.value) &&
              _hasWord(combinedText, foodPreferences[entry.key]!))
            entry.key,
      ];
      var score = matchedRequestedFoods.length * 10;

      // Saved likes affect ordering only and never become mandatory matches.
      for (final label in normalizedSavedLabels.where(
        (value) => value.startsWith('pref_'),
      )) {
        final food = preferenceToFood[label];
        if (food == null || explicitlyExcludedFoods.contains(food)) continue;
        if (_hasWord(combinedText, foodPreferences[label]!)) {
          score += 1;
        }
      }

      final reasons = <String>[
        for (final label in matchedPreferenceLabels)
          'Matches ${label.substring('pref_'.length)}',
        if (budget != null) 'Within ₱${budget.toStringAsFixed(0)} budget',
      ];

      for (final entry in mealTimes.entries) {
        if (rankingLabels.contains(entry.key) &&
            _hasWord(listingText, entry.value)) {
          score += 2;
          reasons.add('Fits requested meal time');
          break;
        }
      }
      if (rankingLabels.contains('budget_friendly')) {
        if (meal.price <= 100) {
          score += 2;
          reasons.add('Budget-friendly');
        } else if (meal.price <= 150) {
          score += 1;
        }
      }

      // Seller-provided details are not independently verified.
      final infoComplete =
          meal.allergenInfoProvided &&
          meal.ingredients.isNotEmpty &&
          meal.allergenDataValid;
      final verificationMessages = <String>[];
      if (!infoComplete) {
        verificationMessages.add(
          'Ingredient/allergen information is missing or incomplete. '
          'Ask the seller before relying on this listing.',
        );
      }
      if (mayContain.isNotEmpty) {
        verificationMessages.add(
          'Seller reports possible cross-contact: '
          '${mayContain.join(', ')}. Verify with the seller.',
        );
      }
      if (meal.allergenNotes.isNotEmpty) {
        verificationMessages.add(
          'Seller allergen notes: ${meal.allergenNotes}. Confirm these details with the seller.',
        );
      }
      if (effectivePatterns.contains('diet_vegan') &&
          _hasWord(combinedText, _ambiguousVeganTerms)) {
        verificationMessages.add(
          'Some ingredients may have either plant or animal sources. '
          'Ask the seller to confirm that all ingredients are vegan.',
        );
      }
      if (safetyRestrictionsActive ||
          activeAvoidLabels.isNotEmpty ||
          effectivePatterns.isNotEmpty) {
        verificationMessages.add(
          'Seller-reported details do not guarantee dietary or allergy suitability. '
          'Confirm all ingredients and cross-contact with the seller.',
        );
      }
      final needsVerification = verificationMessages.isNotEmpty;
      final verificationMessage = verificationMessages.join(' ');

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

    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      final priceOrder = a.meal.price.compareTo(b.meal.price);
      if (priceOrder != 0) return priceOrder;
      return a.meal.name.compareTo(b.meal.name);
    });
    return ranked;
  }
}