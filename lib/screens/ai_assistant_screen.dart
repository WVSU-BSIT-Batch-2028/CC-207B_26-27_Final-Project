import 'package:flutter/material.dart';

import '../services/dietary_preference_service.dart';
import '../services/ai_service.dart';
import '../services/meal_service.dart';
import 'dietary_settings_screen.dart';

/// Student-facing meal search using published Strapi listings and FoodWise AI.
class AiAssistantScreen extends StatefulWidget {
  /// When embedded, StudentNavigationScreen owns the outer Scaffold/header.
  final bool embedded;

  /// Indicates whether this tab is currently visible.
  final bool isActive;

  const AiAssistantScreen({
    super.key,
    this.embedded = false,
    this.isActive = true,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  static const _background = Color(0xFFFFF8F1);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFFE96B10);
  static const _paleOrange = Color(0xFFFFF1E5);
  static const _charcoal = Color(0xFF30251F);
  static const _muted = Color(0xFF88786E);
  static const _border = Color(0xFFF0DFD2);
  static const _danger = Color(0xFFB33A2B);
  static const _green = Color(0xFF39764A);

  final _text = TextEditingController();
  final _ai = FoodWiseAiService();

  List<FoodWiseMeal> _meals = [];
  List<FoodWiseMealMatch> _matches = [];
  FoodWiseAiResult? _result;
  final Set<String> _acceptedSuggestions = {};

  bool _busy = true;
  String? _error;
  DietaryPreferences _saved = const DietaryPreferences();

  static const Map<String, String> _labels = {
    'pref_chicken': 'Chicken',
    'pref_fish': 'Fish',
    'pref_vegetables': 'Vegetables',
    'pref_rice': 'Rice',
    'pref_noodles': 'Noodles',
    'pref_egg': 'Eggs',
    'pref_fruit': 'Fruit',
    'diet_vegetarian': 'Vegetarian',
    'diet_vegan': 'Vegan',
    'meal_breakfast': 'Breakfast',
    'meal_lunch': 'Lunch',
    'meal_dinner': 'Dinner',
    'meal_snack': 'Merienda',
    'budget_friendly': 'Budget-friendly',
    'filling': 'Filling',
    'avoid_spicy': 'Avoid spicy',
    'avoid_dairy': 'Avoid dairy',
    'avoid_peanuts': 'Avoid peanuts',
    'avoid_seafood': 'Avoid seafood',
    'avoid_egg': 'Avoid eggs',
    'avoid_gluten': 'Avoid gluten',
    'allergy_peanuts': 'Peanut allergy',
    'allergy_dairy': 'Dairy allergy',
    'allergy_seafood': 'Seafood allergy',
    'allergy_egg': 'Egg allergy',
    'allergy_gluten': 'Reported gluten allergy',
    'restriction_gluten': 'Strict gluten restriction',
  };

  static const Map<String, String> _avoidLabelToFood = {
    'avoid_spicy': 'spicy',
    'avoid_dairy': 'dairy',
    'avoid_peanuts': 'peanuts',
    'avoid_seafood': 'seafood',
    'avoid_egg': 'egg',
    'avoid_gluten': 'gluten',
  };

  static const Map<String, String> _safetyLabelToFood = {
    'allergy_peanuts': 'peanuts',
    'allergy_dairy': 'dairy',
    'allergy_seafood': 'seafood',
    'allergy_egg': 'egg',
    'allergy_gluten': 'gluten',
    'restriction_gluten': 'gluten',
  };

  String _friendly(String label) =>
      _labels[label] ?? label.replaceAll('_', ' ');

  String _friendlyFood(String food) {
    switch (food) {
      case 'egg':
        return 'eggs';
      case 'vegetables':
        return 'vegetables';
      case 'noodles':
        return 'noodles';
      default:
        return food.isEmpty
            ? food
            : '${food[0].toUpperCase()}${food.substring(1)}';
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Do not display personalized results until saved restrictions are read.
      final saved = await DietaryPreferenceService.load();
      await _ai.initialize();
      final meals = await FoodWiseMealService.fetchAvailableMeals();

      if (!mounted) return;
      setState(() {
        _saved = saved;
        _meals = meals;
        _updateMatches();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPreferences() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DietarySettingsScreen()),
    );

    if (!mounted) return;

    try {
      final saved = await DietaryPreferenceService.load();
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _updateMatches();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh your dietary profile. Try again.'),
        ),
      );
    }
  }

  void _analyze() {
    final request = _text.text.trim();
    if (request.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    final result = _ai.analyze(request);

    setState(() {
      _result = result;
      _acceptedSuggestions.clear();
      _updateMatches();
    });
  }

  void _updateMatches() {
    final result = _result;
    if (result == null) return;

    _matches = FoodWiseMealService.rank(
      meals: _meals,
      interpretation: result,
      acceptedSuggestions: _acceptedSuggestions,
      savedLabels: _saved.labels,
      savedAlwaysExcludeLabels: _saved.alwaysExcludeLabels,
      budget: FoodWiseMealService.extractBudget(result.request),
    );
  }

  Set<String> _overriddenSavedPreferences(FoodWiseAiResult result) {
    final requested = result.requestedFoods.toSet();
    final overridden = <String>{};

    for (final label in _saved.flexibleAvoidances) {
      final food = _avoidLabelToFood[label];
      if ((food != null && requested.contains(food)) ||
          (label == 'avoid_seafood' && requested.contains('fish'))) {
        overridden.add(label);
      }
    }

    final animalFoods = requested.intersection({'chicken', 'fish', 'seafood'});
    if (_saved.dietaryPatterns.contains('diet_vegetarian') &&
        animalFoods.isNotEmpty) {
      overridden.add('diet_vegetarian');
    }

    final veganConflicts = requested.intersection({
      'chicken',
      'fish',
      'seafood',
      'egg',
      'dairy',
    });
    if (_saved.dietaryPatterns.contains('diet_vegan') &&
        veganConflicts.isNotEmpty) {
      overridden.add('diet_vegan');
    }

    return overridden;
  }

  Set<String> _nonOverrideableConflicts(FoodWiseAiResult result) {
    final requested = result.requestedFoods.toSet();
    final conflicts = <String>{};

    for (final label in _saved.safetyRestrictions) {
      final food = _safetyLabelToFood[label];
      if (food != null && requested.contains(food)) {
        conflicts.add(_friendly(label));
      }
    }

    for (final label in _saved.alwaysExcludeLabels) {
      final food = _avoidLabelToFood[label];
      if (food != null && requested.contains(food)) {
        conflicts.add(_friendly(label));
      }
      if (label == 'avoid_seafood' && requested.contains('fish')) {
        conflicts.add(_friendly(label));
      }
    }

    if (_saved.safetyRestrictions.contains('allergy_seafood') &&
        requested.contains('fish')) {
      conflicts.add(_friendly('allergy_seafood'));
    }

    return conflicts;
  }

  @override
  void dispose() {
    _text.dispose();
    _ai.dispose();
    super.dispose();
  }

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _pill(String label, {Color color = _primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color == _primary ? _charcoal : color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _profileGroup(
    String title,
    Iterable<String> labels, {
    Color color = _muted,
  }) {
    final items = labels.toList()..sort();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final label in items) _pill(_friendly(label), color: color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    final summary = <String>[
      if (_saved.safetyRestrictions.isNotEmpty)
        '${_saved.safetyRestrictions.length} safety',
      if (_saved.dietaryPatterns.isNotEmpty)
        '${_saved.dietaryPatterns.length} pattern',
      if (_saved.flexibleAvoidances.isNotEmpty ||
          _saved.alwaysExcludeLabels.isNotEmpty)
        '${_saved.flexibleAvoidances.length + _saved.alwaysExcludeLabels.length} avoid',
      if (_saved.likedFoods.isNotEmpty) '${_saved.likedFoods.length} likes',
    ].join(' · ');

    final hasProfile = _saved.labels.isNotEmpty;

    return _panel(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _paleOrange,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dietary profile',
                      style: TextStyle(
                        color: _charcoal,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasProfile ? summary : 'No saved filters yet',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _editPreferences,
                child: const Text('Edit'),
              ),
            ],
          ),
          if (hasProfile)
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                dense: true,
                title: const Text(
                  'View saved settings',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  _profileGroup(
                    'Safety restrictions',
                    _saved.safetyRestrictions,
                    color: _danger,
                  ),
                  _profileGroup(
                    'Always exclude',
                    _saved.alwaysExcludeLabels,
                    color: _danger,
                  ),
                  _profileGroup(
                    'Flexible preferences',
                    _saved.flexibleAvoidances,
                    color: _primary,
                  ),
                  _profileGroup(
                    'Eating patterns',
                    _saved.dietaryPatterns,
                    color: _green,
                  ),
                  _profileGroup(
                    'Foods you like',
                    _saved.likedFoods,
                    color: _muted,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF4D8BD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _primary, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Allergy and medical details are seller-reported. Confirm ingredients and cross-contact directly.',
              style: TextStyle(color: _charcoal, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummary(FoodWiseAiResult result, double? budget) {
    final understood = <String>{};
    for (final label in result.detectedLabels) {
      if (!label.startsWith('avoid_')) understood.add(_friendly(label));
    }

    for (final food in result.excludedFoods) {
      understood.add('No ${_friendlyFood(food)}');
    }

    for (final food in result.requestedFoods) {
      if (!{
        'chicken',
        'fish',
        'vegetables',
        'rice',
        'noodles',
        'egg',
        'fruit',
      }.contains(food)) {
        understood.add(_friendlyFood(food));
      }
    }

    if (budget != null) {
      understood.add('Up to ₱${budget.toStringAsFixed(0)}');
    }

    final overrides = _overriddenSavedPreferences(result);
    final conflicts = _nonOverrideableConflicts(result);

    return _panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search filters',
            style: TextStyle(
              color: _charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 9),
          if (understood.isEmpty)
            const Text(
              'No specific filters detected.',
              style: TextStyle(color: _muted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final item in understood) _pill(item)],
            ),
          if (overrides.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tune_rounded, color: _primary, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'One-time exception: ${overrides.map(_friendly).join(', ')}.',
                    style: const TextStyle(color: _charcoal, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: _danger, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Kept active: ${conflicts.join(', ')}. This request conflicts with a non-overrideable setting.',
                    style: const TextStyle(color: _danger, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions(List<FoodWiseAiSuggestion> suggestions) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return _panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: const Text(
            'Optional refinements',
            style: TextStyle(
              color: _charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: const Text(
            'Review before applying',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          children: [
            for (final suggestion in suggestions)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: _primary,
                value: _acceptedSuggestions.contains(suggestion.label),
                title: Text(
                  _friendly(suggestion.label),
                  style: const TextStyle(fontSize: 13, color: _charcoal),
                ),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _acceptedSuggestions.add(suggestion.label);
                    } else {
                      _acceptedSuggestions.remove(suggestion.label);
                    }
                    _updateMatches();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _mealCard(FoodWiseMealMatch item) {
    final meal = item.meal;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 88,
                    height: 88,
                    color: _paleOrange,
                    child: meal.imageUrl != null
                        ? Image.network(
                            meal.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.restaurant_rounded,
                              color: _primary,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.restaurant_rounded,
                            color: _primary,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: const TextStyle(
                          color: _charcoal,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${meal.business} · ${meal.category}',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '₱${meal.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (meal.description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          meal.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _charcoal,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.needsIngredientVerification)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _primary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Seller details need checking',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              dense: true,
              title: const Text(
                'Ingredients & seller details',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                if (meal.ingredients.isNotEmpty)
                  _detailLine('Ingredients', meal.ingredients),
                if (meal.containsAllergens.isNotEmpty)
                  _detailLine(
                    'Reported contains',
                    meal.containsAllergens.join(', '),
                  ),
                if (meal.mayContainAllergens.isNotEmpty)
                  _detailLine(
                    'May contain',
                    meal.mayContainAllergens.join(', '),
                  ),
                if (meal.allergenNotes.isNotEmpty)
                  _detailLine('Seller notes', meal.allergenNotes),
                if (item.verificationMessage.isNotEmpty)
                  _detailLine('Please note', item.verificationMessage),
                if (meal.ingredients.isEmpty &&
                    meal.containsAllergens.isEmpty &&
                    meal.mayContainAllergens.isEmpty &&
                    meal.allergenNotes.isEmpty)
                  const Text(
                    'No ingredient details were provided for this listing.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: _charcoal, fontSize: 12, height: 1.4),
            children: [
              TextSpan(
                text: '$title: ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final budget = result == null
        ? null
        : FoodWiseMealService.extractBudget(result.request);
    final safetyVerificationNeeded =
        result != null &&
        (_saved.safetyRestrictions.isNotEmpty ||
            result.restrictionsToConfirm.isNotEmpty);
    final suggestions = result?.aiSuggestions ?? const <FoodWiseAiSuggestion>[];

    final pageContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              'What are you craving?',
              style: TextStyle(
                color: _charcoal,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Search in English, Filipino or Taglish.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _profileCard(),
            const SizedBox(height: 12),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _analyze(),
                    decoration: InputDecoration(
                      hintText: 'e.g. Chicken rice under ₱150',
                      filled: true,
                      fillColor: _background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      ActionChip(
                        label: const Text('Chicken + rice'),
                        onPressed: () => setState(
                          () => _text.text = 'Chicken and rice for lunch',
                        ),
                      ),
                      ActionChip(
                        label: const Text('Budget merienda'),
                        onPressed: () => setState(
                          () => _text.text = 'Affordable merienda under ₱100',
                        ),
                      ),
                      ActionChip(
                        label: const Text('Vegetarian'),
                        onPressed: () =>
                            setState(() => _text.text = 'Vegetarian dinner'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _analyze,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(_busy ? 'Loading menu...' : 'Find my meals'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator(color: _primary)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Food listings are unavailable.',
                      style: TextStyle(
                        color: _danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Check your connection and try again.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    TextButton.icon(
                      onPressed: _initialize,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
            if (!_busy && _error == null)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(
                  '${_meals.length} menu listings available',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            if (result != null && !_busy && _error == null) ...[
              const SizedBox(height: 12),
              _buildSearchSummary(result, budget),
              if (safetyVerificationNeeded) ...[
                const SizedBox(height: 10),
                _buildSafetyNotice(),
              ],
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildSuggestions(suggestions),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    safetyVerificationNeeded
                        ? 'Menu options to verify'
                        : 'Matching meals',
                    style: const TextStyle(
                      color: _charcoal,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_matches.length} found',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_matches.isEmpty)
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        color: _muted,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No matching meals found.',
                        style: TextStyle(
                          color: _charcoal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nonOverrideableConflicts(result).isNotEmpty
                            ? 'Your request conflicts with a saved safety restriction or Always exclude setting. That setting remains active.'
                            : 'Try changing your food request or budget. Your saved safety restrictions will remain active.',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final match in _matches.take(30)) _mealCard(match),
              if (_matches.length > 30)
                Text(
                  'Showing the top 30 of ${_matches.length} meals.',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
            ],
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: _background, child: pageContent);
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _charcoal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI Meal Assistant',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(child: pageContent),
    );
  }
}