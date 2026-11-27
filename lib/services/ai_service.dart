import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

/// A tentative neural-network interpretation. Never automatically enforce it.
class FoodWiseAiSuggestion {
  const FoodWiseAiSuggestion({required this.label, required this.score});

  final String label;
  final double score;
}

class FoodWiseAiResult {
  const FoodWiseAiResult({
    required this.request,
    required this.detectedLabels,
    required this.aiSuggestions,
    required this.restrictionsToConfirm,
    this.excludedFoods = const <String>[],
    this.requestedFoods = const <String>[],
    this.modelError,
  });

  final String request;
  final List<String> detectedLabels;
  final List<FoodWiseAiSuggestion> aiSuggestions;
  final List<String> restrictionsToConfirm;

  /// Foods explicitly rejected in the current request. These are hard
  /// exclusions and must override likes or optional model suggestions.
  final List<String> excludedFoods;

  /// Foods positively requested in the current search. Used only to relax
  /// flexible saved preferences and eating patterns for this search.
  final List<String> requestedFoods;

  /// When set, explicit parsing still worked but the ML model was unavailable.
  final String? modelError;
}

/// FoodWise on-device hybrid interpreter.
///
/// Initialize once before calling analyze(). Explicit rules remain available
/// if the LiteRT model fails to load. AI outputs are suggestions only.
class FoodWiseAiService {
  static const String _assets = 'assets/ai';

  static const Set<String> _safetyLabels = {
    'allergy_peanuts',
    'allergy_dairy',
    'allergy_seafood',
    'allergy_egg',
    'allergy_gluten',
    'restriction_gluten',
  };

  static const Set<String> _softLabels = {
    'meal_breakfast',
    'meal_lunch',
    'meal_dinner',
    'meal_snack',
    'pref_chicken',
    'pref_fish',
    'pref_vegetables',
    'pref_rice',
    'pref_noodles',
    'pref_egg',
    'pref_fruit',
    'diet_vegetarian',
    'diet_vegan',
    'budget_friendly',
    'filling',
  };

  static const Map<String, String> _words = {
    'chicken': r'chicken|manok',
    'fish': r'fish|isda',
    'vegetables': r'vegetables?|veggies|gulay',
    'rice': r'rice|kanin',
    'noodles': r'noodles?|pancit|ramen|pasta|mami',
    'egg': r'eggs?|itlog',
    'fruit': r'fruits?|prutas',
    'spicy': r'spicy|chilli|chili|maanghang|hot sauce',
    'dairy': r'dairy|milk|gatas|cheese|keso|butter|cream',
    'peanuts': r'peanuts?|mani|groundnuts?',
    'seafood': r'seafood|shellfish|shrimp|prawns?|hipon|lamang dagat|fish|isda',
    'gluten': r'gluten|wheat|trigo',
  };

  /// Expanded terms for direct food exclusions. Seafood is deliberately
  /// separate from fish so "no fish" does not automatically reject shellfish.
  static const Map<String, String> _excludedFoodWords = {
    'chicken': r'chicken|manok',
    'fish': r'fish|isda|bangus|tilapia|salmon|tuna|sardines?|anchovies?|mackerel|cod',
    'vegetables': r'vegetables?|veggies|gulay|salad|carrots?|tomatoes?|potatoes?|cabbage|lettuce|broccoli|spinach|pechay|kangkong|eggplant|talong|okra|squash|kalabasa|sitaw|ampalaya',
    'rice': r'rice|kanin|sinangag|silog|tapsilog|longsilog|hotsilog|fried rice|garlic rice',
    'noodles': r'noodles?|pancit|ramen|pasta|mami|spaghetti|sotanghon|bihon|misua|udon|soba|macaroni',
    'egg': r'eggs?|itlog|mayonnaise|mayo|albumin|egg white|egg yolk|egg powder',
    'fruit': r'fruits?|prutas|banana|mango|apple|orange|pineapple|papaya|watermelon|melon|grapes?|strawberr(y|ies)|avocado',
    'spicy': r'spicy|chilli|chili|maanghang|hot sauce|sriracha|cayenne|jalapeno|siling labuyo|siling haba',
    'dairy': r'dairy|milk|gatas|cheese|keso|butter|cream|yogurt|yoghurt|whey|casein|lactose|buttermilk|ghee',
    'peanuts': r'peanuts?|mani|groundnuts?|peanut butter|peanut sauce',
    'seafood': r'seafood|shellfish|shrimp|prawns?|hipon|crab|lobster|oyster|mussel|clam|scallop|squid|octopus|lamang dagat|lamang-dagat',
    'gluten': r'gluten|wheat|trigo|barley|rye|triticale|malt|seitan|semolina|durum|bulgur|couscous',
  };

  /// Preference labels that can be suggested by the model. A matching direct
  /// exclusion always takes priority over these positive labels.
  static const Map<String, String> _preferenceFoods = {
    'pref_chicken': 'chicken',
    'pref_fish': 'fish',
    'pref_vegetables': 'vegetables',
    'pref_rice': 'rice',
    'pref_noodles': 'noodles',
    'pref_egg': 'egg',
    'pref_fruit': 'fruit',
  };

  static const Map<String, String> _meals = {
    'meal_breakfast': r'breakfast|almusal|umaga|this morning',
    'meal_lunch': r'lunch|tanghalian|midday|noon',
    'meal_dinner': r'dinner|supper|hapunan|tonight|gabi',
    'meal_snack': r'snack|merienda|meryenda',
  };

  static const String _negate =
      r'(?:no|not|without|avoid|exclude|skip|leave out|do not want|dont want|do not eat|dont eat|do not like|dont like|walang|ayoko ng|ayaw ko ng|hindi ako kumakain ng|wag|pakiwasan|bawal)';

  static const String _restriction =
      r'doctor|medical|strict|must|require|restriction|dietary restriction|kailangan|bawal sa diet';

  Interpreter? _interpreter;
  Map<String, int> _wordToIndex = {};
  List<String> _labels = [];
  int _sequenceLength = 32;
  double _threshold = 0.75;
  String? _modelError;

  bool get modelReady => _interpreter != null;
  String? get modelError => _modelError;

  Future<void> initialize() async {
    if (_interpreter != null) return;
    try {
      final vocabularyJson = jsonDecode(
        await rootBundle.loadString('$_assets/vocabulary.json'),
      ) as Map<String, dynamic>;
      final configJson = jsonDecode(
        await rootBundle.loadString('$_assets/model_config.json'),
      ) as Map<String, dynamic>;
      final labelJson = jsonDecode(
        await rootBundle.loadString('$_assets/labels.json'),
      ) as List<dynamic>;

      final vocabulary = (vocabularyJson['vocabulary'] as List<dynamic>)
          .map((word) => word.toString())
          .toList();
      _wordToIndex = {
        for (var i = 0; i < vocabulary.length; i++) vocabulary[i]: i,
      };
      _labels = labelJson.map((label) => label.toString()).toList();
      _sequenceLength = (vocabularyJson['max_sequence_length'] as num).toInt();
      _threshold = (configJson['confidence_threshold'] as num).toDouble();

      // Required for Flutter Web; a no-op on Android/iOS/desktop.
      await initializeWeb();
      final interpreter = await Interpreter.fromAsset(
        '$_assets/foodwise_intent.tflite',
      );
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (inputShape.length != 2 ||
          inputShape.last != _sequenceLength ||
          outputShape.length != 2 ||
          outputShape.last != _labels.length) {
        interpreter.close();
        throw StateError(
          'FoodWise model dimensions do not match the JSON assets.',
        );
      }
      _interpreter = interpreter;
      _modelError = null;
    } catch (error) {
      _modelError = error.toString();
      // The explicit parser remains usable without the neural network.
    }
  }

  FoodWiseAiResult analyze(String request) {
    final excludedFoods = _extractExcludedFoods(request);
    final explicit = _extractExplicit(
      request,
      excludedFoods: excludedFoods.toSet(),
    );
    final requestedFoods = _extractRequestedFoods(
      request,
      excludedFoods: excludedFoods.toSet(),
      detectedLabels: explicit,
    );
    final suggestions = <FoodWiseAiSuggestion>[];

    if (_interpreter != null && request.trim().isNotEmpty) {
      try {
        final tokens = _encodeForModel(request);
        final output = [List<double>.filled(_labels.length, 0.0)];
        _interpreter!.run([tokens], output);
        for (var i = 0; i < _labels.length; i++) {
          final label = _labels[i];
          final score = output[0][i];
          if (score < _threshold || !_softLabels.contains(label)) continue;
          if (explicit.contains(label)) continue;
          if (_skipUnsupportedSuggestion(
            label,
            explicit,
            excludedFoods: excludedFoods.toSet(),
          )) {
            continue;
          }
          suggestions.add(FoodWiseAiSuggestion(label: label, score: score));
        }
        suggestions.sort((a, b) => b.score.compareTo(a.score));
        if (suggestions.length > 3) {
          suggestions.removeRange(3, suggestions.length);
        }
      } catch (error) {
        _modelError = error.toString();
      }
    }

    return FoodWiseAiResult(
      request: request,
      detectedLabels: explicit,
      aiSuggestions: suggestions,
      restrictionsToConfirm: explicit.where(_safetyLabels.contains).toList(),
      excludedFoods: excludedFoods,
      requestedFoods: requestedFoods,
      modelError: _modelError,
    );
  }

  List<int> _encodeForModel(String text) {
    // Exactly matches Python: lowercase, strip ASCII punctuation,
    // normalize whitespace, split into words, pad with zero.
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = normalized.isEmpty ? <String>[] : normalized.split(' ');
    final ids = words
        .take(_sequenceLength)
        .map((word) => _wordToIndex[word] ?? 1)
        .toList();
    while (ids.length < _sequenceLength) {
      ids.add(0);
    }
    return ids;
  }

  bool _skipUnsupportedSuggestion(
    String label,
    List<String> explicit, {
    Set<String> excludedFoods = const <String>{},
  }) {
    final suggestedFood = _preferenceFoods[label];
    if (suggestedFood != null && excludedFoods.contains(suggestedFood)) {
      return true;
    }

    // These are dependable only when the user actually requests them.
    // Prevents the observed false 'budget_friendly' guess for breakfast.
    if (label == 'budget_friendly' || label == 'filling') return true;

    final known = explicit.toSet();
    if (label.startsWith('meal_') &&
        known.any((item) => item.startsWith('meal_'))) {
      return true;
    }
    if (label.startsWith('pref_') &&
        known.any((item) => item.startsWith('pref_'))) {
      return true;
    }
    if (label.startsWith('diet_') &&
        known.any((item) => item.startsWith('diet_'))) {
      return true;
    }

    if (label == 'pref_egg' &&
        (known.contains('avoid_egg') ||
            known.contains('allergy_egg') ||
            known.contains('diet_vegan'))) {
      return true;
    }
    if (label == 'pref_fish' &&
        (known.contains('avoid_seafood') ||
            known.contains('allergy_seafood') ||
            known.contains('diet_vegan') ||
            known.contains('diet_vegetarian'))) {
      return true;
    }
    if (label == 'pref_chicken' &&
        (known.contains('diet_vegan') || known.contains('diet_vegetarian'))) {
      return true;
    }
    if (label == 'diet_vegan' &&
        known.any({'pref_egg', 'pref_fish', 'pref_chicken'}.contains)) {
      return true;
    }
    if (label == 'diet_vegetarian' &&
        known.any({'pref_fish', 'pref_chicken'}.contains)) {
      return true;
    }
    return false;
  }

  String _normalizeForRules(String text) {
    var result = text.toLowerCase().replaceAll('’', "'");
    result = result
        .replaceAll("don't", 'dont')
        .replaceAll("won't", 'wont')
        .replaceAll("can't", 'cant');
    result = result.replaceAll(RegExp(r'[.;!?]'), ' but ');
    result = result.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _has(String text, String pattern) =>
      RegExp(r'\b(?:' + pattern + r')\b').hasMatch(text);

  bool _explicitAvoid(String text, String pattern) {
    final expression = RegExp(
      r'\b' +
          _negate +
          r'\b' +
          r'(?:\s+(?:any|the|my|all|a|an|some|added|containing|include|add|put|use|eat|want|have|food|ingredients?)){0,3}' +
          r'\s+(?:' +
          pattern +
          r')\b',
    );
    final freePattern = RegExp(r'\b(?:' + pattern + r')\s+free\b');
    return expression.hasMatch(text) || freePattern.hasMatch(text);
  }

  bool _reportedAllergy(String text, String pattern) {
    final clauses = text.split(
      RegExp(
        r'\b(?:but|pero|however|and\s+(?:want|prefer|like|need)|at\s+gusto|gusto\s+ko|i\s+want|i\s+prefer)\b',
      ),
    );
    final allergyPattern = RegExp(
      r'\b(?:allerg(?:y|ies|ic)|allergic|allergically)\b',
    );
    final itemPattern = RegExp(r'\b(?:' + pattern + r')\b');
    for (final clause in clauses) {
      if (RegExp(r'\b(?:not|no)\s+allerg').hasMatch(clause)) continue;
      for (final clue in allergyPattern.allMatches(clause)) {
        for (final item in itemPattern.allMatches(clause)) {
          final distance = clue.end <= item.start
              ? item.start - clue.end
              : (item.end <= clue.start ? clue.start - item.end : 0);
          if (distance <= 32) return true;
        }
      }
    }
    return false;
  }

  /// Extracts direct food exclusions independently from positive food likes.
  /// Examples: "I don't want chicken", "no chicken or fish", and
  /// "without eggs". A contrast/positive clause starts a new scope so
  /// "no chicken, but I like fish" does not reject fish.
  List<String> _extractExcludedFoods(String text) {
    var normalized = text.toLowerCase().replaceAll('’', "'");
    normalized = normalized
        .replaceAll("don't", 'dont')
        .replaceAll("won't", 'wont')
        .replaceAll("can't", 'cant');

    // Keep coordinated exclusions together, but split clear new clauses.
    normalized = normalized.replaceAll(RegExp(r'[.;!?]'), ' | ');
    normalized = normalized.replaceAll(
      RegExp(
        r',\s*(?=(?:i\s+(?:want|like|prefer|need|would\s+like)|gusto\s+ko|mas\s+gusto|prefer|want|like)\b)',
      ),
      ' | ',
    );
    normalized = normalized.replaceAll(RegExp(r'[^\w\s|]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    final clauses = normalized.split(
      RegExp(r'\b(?:but|however|except|instead|although|though|pero)\b|\|'),
    );
    final negationPattern = RegExp(
      r'\b(?:no|not|without|avoid|exclude|skip|leave\s+out|do\s+not\s+want|dont\s+want|do\s+not\s+eat|dont\s+eat|do\s+not\s+like|dont\s+like|walang|ayoko\s+ng|ayaw\s+ko\s+ng|hindi\s+ako\s+kumakain\s+ng|wag|pakiwasan|bawal)\b',
    );
    final positiveBoundary = RegExp(
      r'\b(?:i\s+(?:want|like|prefer|need|would\s+like)|gusto\s+ko(?:\s+ng)?|mas\s+gusto\s+ko(?:\s+ng)?|okay\s+with|fine\s+with)\b',
    );
    final excluded = <String>{};

    for (final clause in clauses) {
      for (final negation in negationPattern.allMatches(clause)) {
        var tail = clause.substring(negation.end);

        // "Not allergic to peanuts" is an allergy denial, not a food exclusion.
        if (negation.group(0) == 'not' &&
            RegExp(r'^\s+allerg').hasMatch(tail)) {
          continue;
        }

        final positiveStart = positiveBoundary.firstMatch(tail);
        if (positiveStart != null) {
          tail = tail.substring(0, positiveStart.start);
        }
        for (final entry in _excludedFoodWords.entries) {
          if (_has(tail, entry.value)) {
            excluded.add(entry.key);
          }
        }
      }

      // Also recognize phrases such as "chicken-free" after punctuation
      // normalization has converted the hyphen to a space.
      for (final entry in _excludedFoodWords.entries) {
        if (RegExp(r'\b(?:' + entry.value + r')\s+free\b').hasMatch(clause)) {
          excluded.add(entry.key);
        }
      }
    }

    return excluded.toList()..sort();
  }

  /// Finds positive food requests separately from exclusions.
  ///
  /// This is intentionally conservative for foods that are also common
  /// allergens: an allergy statement or an allergy denial is not treated as
  /// a request to eat that food.
  List<String> _extractRequestedFoods(
    String text, {
    required Set<String> excludedFoods,
    required List<String> detectedLabels,
  }) {
    const preferenceLabels = <String, String>{
      'pref_chicken': 'chicken',
      'pref_fish': 'fish',
      'pref_vegetables': 'vegetables',
      'pref_rice': 'rice',
      'pref_noodles': 'noodles',
      'pref_egg': 'egg',
      'pref_fruit': 'fruit',
    };

    final requested = <String>{
      for (final entry in preferenceLabels.entries)
        if (detectedLabels.contains(entry.key)) entry.value,
    };

    final normalized = _normalizeForRules(text);
    const flexibleFoods = <String, String>{
      'spicy': r'spicy|chilli|chili|maanghang|hot sauce|sriracha',
      'dairy': r'dairy|milk|gatas|cheese|keso|butter|cream|yogurt|yoghurt',
      'peanuts': r'peanuts?|mani|groundnuts?|peanut butter|peanut sauce',
      'seafood': r'seafood|shellfish|shrimp|prawns?|hipon|crab|lobster|oyster|mussel|clam|scallop|squid|octopus|lamang dagat',
      'gluten': r'gluten|wheat|trigo|barley|rye|malt|seitan|bread|flour',
    };
    final positiveIntent = RegExp(
      r'\b(?:i\s+(?:want|like|prefer|crave|need)|i\s+am\s+craving|'
      r'looking\s+for|gusto\s+ko(?:\s+ng)?|mas\s+gusto\s+ko(?:\s+ng)?|'
      r'craving|with|containing|include|add)\b',
    );
    final allergyDenial = RegExp(r'\b(?:not|no)\s+allerg\w*\b');

    for (final entry in flexibleFoods.entries) {
      if (excludedFoods.contains(entry.key) ||
          _reportedAllergy(normalized, entry.value)) {
        continue;
      }

      final foodMatches = RegExp(r'\b(?:' + entry.value + r')\b')
          .allMatches(normalized);
      for (final foodMatch in foodMatches) {
        final start = (foodMatch.start - 64)
            .clamp(0, normalized.length)
            .toInt();
        final prefix = normalized.substring(start, foodMatch.start);
        final nearby = normalized.substring(
          foodMatch.start,
          (foodMatch.end + 28).clamp(0, normalized.length).toInt(),
        );

        // "I'm not allergic to peanuts" is not an instruction to include
        // peanuts. A later explicit "I want peanuts" can still be recognized.
        final deniedAllergyNearby =
            allergyDenial.hasMatch(prefix) && !positiveIntent.hasMatch(prefix);
        if (deniedAllergyNearby) continue;

        if (positiveIntent.hasMatch(prefix) ||
            foodMatch.start <= 12 ||
            positiveIntent.hasMatch(nearby)) {
          requested.add(entry.key);
          break;
        }
      }
    }

    return requested.toList()..sort();
  }

  List<String> _extractExplicit(
    String text, {
    Set<String> excludedFoods = const <String>{},
  }) {
    final normalized = _normalizeForRules(text);
    final found = <String>{};

    for (final entry in _meals.entries) {
      if (_has(normalized, entry.value)) found.add(entry.key);
    }
    if (_has(normalized, r'vegan|plant based')) {
      found.add('diet_vegan');
    } else if (_has(normalized, r'vegetarian|meat free')) {
      found.add('diet_vegetarian');
    }
    if (_has(
      normalized,
      r'affordable|cheap|inexpensive|budget|murang|mura|tipid|sulit',
    )) {
      found.add('budget_friendly');
    }
    if (_has(
      normalized,
      r'filling|satisfying|satisfied|hearty|nakakabusog|busog|substantial',
    )) {
      found.add('filling');
    }

    const avoid = {
      'spicy': 'avoid_spicy',
      'dairy': 'avoid_dairy',
      'peanuts': 'avoid_peanuts',
      'seafood': 'avoid_seafood',
      'egg': 'avoid_egg',
      'gluten': 'avoid_gluten',
    };
    for (final entry in avoid.entries) {
      final pattern = entry.key == 'seafood'
          ? _excludedFoodWords['seafood']!
          : _words[entry.key]!;
      if (_explicitAvoid(normalized, pattern)) {
        found.add(entry.value);
      }
    }

    const allergies = {
      'peanuts': 'allergy_peanuts',
      'dairy': 'allergy_dairy',
      'seafood': 'allergy_seafood',
      'egg': 'allergy_egg',
      'gluten': 'allergy_gluten',
    };
    for (final entry in allergies.entries) {
      if (_reportedAllergy(normalized, _words[entry.key]!)) {
        found.add(entry.value);
      }
    }
    if (_has(normalized, _words['gluten']!) && _has(normalized, _restriction)) {
      found.add('restriction_gluten');
      found.remove('avoid_gluten');
    }

    const preferences = {
      'chicken': 'pref_chicken',
      'fish': 'pref_fish',
      'vegetables': 'pref_vegetables',
      'rice': 'pref_rice',
      'noodles': 'pref_noodles',
      'egg': 'pref_egg',
      'fruit': 'pref_fruit',
    };
    for (final entry in preferences.entries) {
      if (!excludedFoods.contains(entry.key) &&
          _has(normalized, _words[entry.key]!)) {
        found.add(entry.value);
      }
    }

    if (found.contains('avoid_egg') || found.contains('allergy_egg')) {
      found.remove('pref_egg');
    }
    if (found.contains('avoid_seafood') || found.contains('allergy_seafood')) {
      found.remove('pref_fish');
    }
    if (found.contains('diet_vegan')) {
      found.removeAll({'pref_chicken', 'pref_fish', 'pref_egg'});
    }
    if (found.contains('diet_vegetarian')) {
      found.removeAll({'pref_chicken', 'pref_fish'});
    }
    return found.toList()..sort();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}