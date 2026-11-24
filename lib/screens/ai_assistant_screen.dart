import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';
import '../widgets/feedback_banner.dart';

import '../services/ai_service.dart';
import '../services/meal_service.dart';
import '../services/dietary_preference_service.dart';

/// Student-facing assistant: real published Strapi foods + on-device AI.
/// Main AI Meal Assistant screen. Open from the student dashboard.
class AiAssistantScreen extends StatefulWidget {
  /// When embedded, the student navigation owns the Scaffold and header.
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
  // Match FoodWiseColors for custom surfaces and const widgets.
  // Standard Material widgets inherit FoodWiseTheme.light from MaterialApp.
  static const _primary = Color(0xFFE96B10);
  static const _charcoal = Color(0xFF30251F);
  static const _background = Color(0xFFFFF8F1);
  static const _surface = Color(0xFFFFFFFF);
  static const _lightOrange = Color(0xFFFFE7D1);
  static const _paleOrange = Color(0xFFFFF1E5);
  static const _muted = Color(0xFF88786E);
  static const _border = Color(0xFFF0DFD2);

  final _text = TextEditingController();
  final _ai = FoodWiseAiService();
  List<FoodWiseMeal> _meals = [];
  List<FoodWiseMealMatch> _matches = [];
  FoodWiseAiResult? _result;
  final Set<String> _acceptedSuggestions = {};
  bool _busy = false;
  bool _modelInitialized = false;
  bool _reloadQueued = false;
  bool _restrictionsConfirmed = false;
  FeedbackData? _error;
  FeedbackData? _requestFeedback;
  DietaryPreferences _saved = const DietaryPreferences();
  bool _savingPreferences = false;

  static const Map<String, String> _options = {
    'pref_chicken': 'Chicken',
    'pref_fish': 'Fish',
    'pref_vegetables': 'Vegetables',
    'pref_rice': 'Rice',
    'pref_noodles': 'Noodles',
    'pref_egg': 'Eggs',
    'pref_fruit': 'Fruit',
    'diet_vegetarian': 'Vegetarian',
    'diet_vegan': 'Vegan',
    'avoid_spicy': 'Avoid spicy',
    'avoid_dairy': 'Avoid dairy',
    'avoid_peanuts': 'Avoid peanuts',
    'avoid_seafood': 'Avoid seafood',
    'avoid_egg': 'Avoid eggs',
    'avoid_gluten': 'Avoid gluten',
    'allergy_peanuts': 'Reported peanut allergy',
    'allergy_dairy': 'Reported dairy allergy',
    'allergy_seafood': 'Reported seafood allergy',
    'allergy_egg': 'Reported egg allergy',
    'allergy_gluten': 'Reported gluten allergy',
    'restriction_gluten': 'Strict gluten restriction',
  };

  String _friendly(String label) =>
      _options[label] ?? label.replaceAll('_', ' ');

  Future<void> _editPreferences() async {
    final editing = <String>{..._saved.labels};
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'My dietary preferences',
            style: TextStyle(color: _charcoal, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose only preferences and restrictions you want FoodWise to remember. You can change them anytime.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  for (final section in [
                    (
                      'Foods I like',
                      _options.keys
                          .where((x) => x.startsWith('pref_'))
                          .toList(),
                    ),
                    ('Eating pattern', ['diet_vegetarian', 'diet_vegan']),
                    (
                      'Foods to avoid',
                      _options.keys
                          .where((x) => x.startsWith('avoid_'))
                          .toList(),
                    ),
                    (
                      'Self-reported allergies / restrictions',
                      _options.keys
                          .where(
                            (x) =>
                                x.startsWith('allergy_') ||
                                x.startsWith('restriction_'),
                          )
                          .toList(),
                    ),
                  ]) ...[
                    Text(
                      section.$1,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final label in section.$2)
                          FilterChip(
                            label: Text(_friendly(label)),
                            selected: editing.contains(label),
                            selectedColor: _lightOrange,
                            backgroundColor: _paleOrange,
                            checkmarkColor: _primary,
                            side: BorderSide(
                              color: editing.contains(label)
                                  ? _primary
                                  : _border,
                            ),
                            labelStyle: const TextStyle(color: _charcoal),
                            onSelected: (on) => updateDialog(() {
                              if (on) {
                                if (label == 'diet_vegan') {
                                  editing.remove('diet_vegetarian');
                                }
                                if (label == 'diet_vegetarian') {
                                  editing.remove('diet_vegan');
                                }
                                editing.add(label);
                              } else {
                                editing.remove(label);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'This is self-reported information, not a medical diagnosis. FoodWise never guarantees that a meal is allergy-safe; verify ingredients and cross-contact with the seller.',
                    style: TextStyle(color: _primary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, editing),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Save preferences'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _savingPreferences = true);
    try {
      final saved = await DietaryPreferenceService.save(picked);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _restrictionsConfirmed = false;
        _updateMatches();
      });
      AppFeedback.show(
        context,
        AppFeedback.success(
          'Preferences saved',
          'Your meal searches will use the updated preferences.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        AppFeedback.fromError(
          error,
          title: 'Unable to save preferences',
          fallback: 'Your changes were not confirmed. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingPreferences = false);
        _runQueuedReload();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant AiAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initialize();
    }
  }

  void _runQueuedReload() {
    if (!mounted || _busy || _savingPreferences || !_reloadQueued) {
      return;
    }
    _reloadQueued = false;
    if (widget.isActive) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (_busy || _savingPreferences) {
      _reloadQueued = true;
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Load stored restrictions before showing any personalized results.
      // If the read fails, do not silently ignore potentially serious allergies.
      final saved = await DietaryPreferenceService.load();
      if (!mounted) return;
      if (!_modelInitialized) {
        await _ai.initialize();
        if (!mounted) return;
        _modelInitialized = true;
      }
      final meals = await FoodWiseMealService.fetchAvailableMeals();
      if (!mounted) return;
      setState(() {
        final preferencesChanged =
            _saved.labels.length != saved.labels.length ||
            !_saved.labels.containsAll(saved.labels);
        if (preferencesChanged) {
          _restrictionsConfirmed = false;
        }
        _saved = saved;
        _meals = meals;
        _updateMatches();
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppFeedback.fromError(
          e,
          title: 'Unable to load the meal assistant',
          fallback: 'Your menu or saved preferences could not load. Try again before searching for meals.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _runQueuedReload();
      }
    }
  }

  void _analyze() {
    final request = _text.text.trim();
    if (_busy || _error != null || _savingPreferences) return;
    if (request.isEmpty) {
      setState(
        () => _requestFeedback = AppFeedback.warning(
          'Enter a meal request',
          'Tell us what you would like to eat.',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      final result = _ai.analyze(request);
      setState(() {
        _requestFeedback = null;
        _result = result;
        _acceptedSuggestions.clear();
        _restrictionsConfirmed = false;
        _updateMatches();
      });
    } catch (error) {
      setState(() {
        _result = null;
        _matches = [];
        _requestFeedback = AppFeedback.fromError(
          error,
          title: 'Unable to find meals',
          fallback: 'Please try your request again.',
        );
      });
    }
  }

  void _updateMatches() {
    final result = _result;
    if (result == null) return;
    _matches = FoodWiseMealService.rank(
      meals: _meals,
      interpretation: result,
      acceptedSuggestions: _acceptedSuggestions,
      savedLabels: _saved.labels,
      restrictionsConfirmed: _restrictionsConfirmed,
      budget: FoodWiseMealService.extractBudget(result.request),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _ai.dispose();
    super.dispose();
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _pill(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color == null ? _paleOrange : color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(
        color: color == null ? _border : color.withValues(alpha: .28),
      ),
    ),
    child: Text(
      label.replaceAll('_', ' '),
      style: const TextStyle(fontSize: 12, color: _charcoal),
    ),
  );

  Widget _mealCard(FoodWiseMealMatch item) {
    final meal = item.meal;
    return _panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _lightOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: meal.imageUrl != null
                ? Image.network(
                    meal.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.restaurant, size: 35, color: _primary),
                  )
                : const Icon(Icons.restaurant, size: 35, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meal.business} · ${meal.category}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 8),
                Text(
                  '₱${meal.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: _primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (meal.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    meal.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _charcoal),
                  ),
                ],
                if (item.reasons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.reasons.take(2).join(' · '),
                    style: const TextStyle(color: _charcoal, fontSize: 12),
                  ),
                ],
                if (meal.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ingredients (seller-reported): ${meal.ingredients}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _charcoal),
                  ),
                ],
                if (meal.containsAllergens.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Contains (seller-reported): ${meal.containsAllergens.join(', ')}',
                    style: const TextStyle(fontSize: 12, color: _primary),
                  ),
                ],
                if (meal.mayContainAllergens.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'May contain: ${meal.mayContainAllergens.join(', ')}',
                    style: const TextStyle(fontSize: 12, color: _primary),
                  ),
                ],
                if (meal.allergenNotes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meal.allergenNotes,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (item.needsIngredientVerification) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: _primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.verificationMessage,
                          style: const TextStyle(fontSize: 12, color: _primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_lightOrange, _paleOrange],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: _surface,
          child: Icon(Icons.auto_awesome_rounded, color: _primary, size: 26),
        ),
        SizedBox(height: 14),
        Text(
          'FOODWISE AI',
          style: TextStyle(
            color: _charcoal,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'What sounds good today?',
          style: TextStyle(
            fontSize: 27,
            color: _charcoal,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Tell FoodWise what you want in English, Filipino, or Taglish. We’ll search real published menu listings.',
          style: TextStyle(color: _charcoal, fontSize: 13, height: 1.5),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final restrictions = result?.restrictionsToConfirm ?? [];
    final hasDietaryPattern =
        result?.detectedLabels.any((label) => label.startsWith('diet_')) ??
        false;
    final needsVerification =
        restrictions.isNotEmpty ||
        hasDietaryPattern ||
        _saved.restrictions.isNotEmpty;
    final suggestions = result?.aiSuggestions ?? [];
    final budget = result == null
        ? null
        : FoodWiseMealService.extractBudget(result.request);

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _buildHero(),
            const SizedBox(height: 18),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: _primary, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'My saved dietary preferences',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _charcoal,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy || _savingPreferences || _error != null
                            ? null
                            : _editPreferences,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: Text(_savingPreferences ? 'Saving...' : 'Edit'),
                      ),
                    ],
                  ),
                  if (_saved.labels.isEmpty)
                    const Text(
                      'Nothing saved yet. Choose foods you like and any restrictions to reuse them for future searches.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    )
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final label in (_saved.labels.toList()..sort()))
                          _pill(_friendly(label)),
                      ],
                    ),
                  if (_saved.restrictions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Saved restrictions are always applied to your searches. Food listings remain seller-reported and require verification.',
                      style: TextStyle(color: _primary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Find your next meal',
                    style: TextStyle(
                      color: _charcoal,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _text,
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: _charcoal),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Gusto ko ng chicken and rice for lunch, under ₱150',
                      fillColor: _background,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Try asking',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final sample in [
                        'Chicken and rice for lunch under ₱150',
                        'Affordable merienda, gusto ko ng pancit',
                        'Vegetarian dinner please',
                      ])
                        ActionChip(
                          backgroundColor: _paleOrange,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          avatar: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: _primary,
                          ),
                          label: Text(
                            sample,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _charcoal,
                            ),
                          ),
                          onPressed: () => setState(() => _text.text = sample),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy || _error != null || _savingPreferences
                        ? null
                        : _analyze,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(_busy ? 'Loading menu...' : 'Find my meals'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: _primary),
                ),
              ),
            if (_error != null) ...[
              FeedbackBanner(
                feedback: FeedbackData(
                  title: _error!.title,
                  message: _error!.message,
                  type: _error!.type,
                  actionLabel: 'Try again',
                ),
                onAction: _initialize,
              ),
              const SizedBox(height: 12),
            ],
            if (_requestFeedback != null) ...[
              FeedbackBanner(
                feedback: _requestFeedback!,
                onDismiss: () => setState(() => _requestFeedback = null),
              ),
              const SizedBox(height: 12),
            ],
            if (!_busy && _error == null)
              Text(
                '${_meals.length} available food listings from Strapi · ${_ai.modelReady ? 'On-device AI loaded' : 'Explicit interpretation fallback'}',
                style: const TextStyle(fontSize: 12, color: _charcoal),
              ),
            if (result != null && !_busy && _error == null) ...[
              const SizedBox(height: 18),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Understood from your request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _charcoal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (result.detectedLabels.isEmpty)
                      const Text(
                        'No specific food preferences detected. Showing available listings, not personalized matches.',
                      ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final label in result.detectedLabels) _pill(label),
                        if (budget != null)
                          _pill('Max ₱${budget.toStringAsFixed(0)}'),
                      ],
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Optional AI suggestions (tap to apply)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final suggestion in suggestions)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: _primary,
                          value: _acceptedSuggestions.contains(
                            suggestion.label,
                          ),
                          title: Text(
                            '${suggestion.label.replaceAll('_', ' ')} · ${(suggestion.score * 100).toStringAsFixed(0)}% model score',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _acceptedSuggestions.add(suggestion.label);
                            } else {
                              _acceptedSuggestions.remove(suggestion.label);
                            }
                            _updateMatches();
                          }),
                        ),
                    ],
                  ],
                ),
              ),
              if (needsVerification) ...[
                const SizedBox(height: 12),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: _primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dietary requirements need verification',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'In this request: ${[...restrictions, if (hasDietaryPattern) ...result.detectedLabels.where((x) => x.startsWith('diet_'))].join(', ')}\nSaved requirements: ${_saved.restrictions.map(_friendly).join(', ')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingredient and allergen information is supplied by businesses and may be incomplete. These are menu options to verify, NOT confirmed allergy-safe foods. Ask the seller about ingredients and cross-contact.',
                        style: TextStyle(fontSize: 12, color: _primary),
                      ),
                      if (restrictions.isNotEmpty || hasDietaryPattern)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: _primary,
                          value: _restrictionsConfirmed,
                          title: const Text(
                            'The restrictions stated in this request are correct',
                            style: TextStyle(fontSize: 12),
                          ),
                          onChanged: (checked) => setState(() {
                            _restrictionsConfirmed = checked ?? false;
                            _updateMatches();
                          }),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      needsVerification
                          ? 'Menu options to verify'
                          : 'Matching meals',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: _charcoal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_matches.length} results',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_matches.isEmpty)
                _panel(
                  child: Text(
                    budget == null
                        ? 'No published food currently matches all the requested preferences and dietary filters. Try fewer food requirements or ask the seller about new menu options.'
                        : 'No published food currently matches all the requested preferences and dietary filters within ₱${budget.toStringAsFixed(0)}. Try adjusting the budget or the requested foods.',
                  ),
                ),
              for (final match in _matches.take(30)) ...[
                _mealCard(match),
                const SizedBox(height: 10),
              ],
              if (_matches.length > 30)
                Text(
                  'Showing the top 30 of ${_matches.length} matches.',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _charcoal,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'AI Meal Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(child: content),
    );
  }
}
