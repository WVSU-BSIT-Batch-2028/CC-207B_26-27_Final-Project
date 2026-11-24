import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';
import '../widgets/feedback_banner.dart';

import '../services/dietary_preference_service.dart';

enum _DietaryFeedbackKind { success, info, error }

class DietarySettingsScreen extends StatefulWidget {
  const DietarySettingsScreen({super.key});

  @override
  State<DietarySettingsScreen> createState() => _DietarySettingsScreenState();
}

class _DietarySettingsScreenState extends State<DietarySettingsScreen> {
  static const _background = Color(0xFFFFF8F1);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFFE96B10);
  static const _lightOrange = Color(0xFFFFE7D1);
  static const _paleOrange = Color(0xFFFFF1E5);
  static const _charcoal = Color(0xFF30251F);
  static const _muted = Color(0xFF88786E);
  static const _border = Color(0xFFF0DFD2);

  static const _likedFoods = <String, String>{
    'pref_chicken': 'Chicken',
    'pref_fish': 'Fish',
    'pref_vegetables': 'Vegetables',
    'pref_rice': 'Rice',
    'pref_noodles': 'Noodles',
    'pref_egg': 'Eggs',
    'pref_fruit': 'Fruit',
  };

  static const _eatingPatterns = <String, String>{
    'diet_vegetarian': 'Vegetarian',
    'diet_vegan': 'Vegan',
  };

  static const _avoidFoods = <String, String>{
    'avoid_spicy': 'Spicy food',
    'avoid_dairy': 'Dairy',
    'avoid_peanuts': 'Peanuts',
    'avoid_seafood': 'Seafood',
    'avoid_egg': 'Eggs',
    'avoid_gluten': 'Gluten',
  };

  static const _allergies = <String, String>{
    'allergy_peanuts': 'Peanut allergy',
    'allergy_dairy': 'Dairy allergy',
    'allergy_seafood': 'Seafood allergy',
    'allergy_egg': 'Egg allergy',
    'allergy_gluten': 'Reported gluten allergy',
    'restriction_gluten': 'Strict gluten restriction',
  };

  Set<String> _saved = <String>{};
  Set<String> _editing = <String>{};
  bool _loadingPreferences = true;
  bool _savingPreferences = false;
  String? _preferencesError;
  String? _dietaryFeedback;
  _DietaryFeedbackKind _dietaryFeedbackKind = _DietaryFeedbackKind.info;

  bool get _dietaryDirty =>
      _editing.length != _saved.length || !_editing.containsAll(_saved);

  bool get _canSave =>
      !_loadingPreferences &&
      _preferencesError == null &&
      !_savingPreferences &&
      _dietaryDirty;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loadingPreferences = true;
      _preferencesError = null;
    });

    try {
      final preferences = await DietaryPreferenceService.load();
      if (!mounted) return;
      setState(() {
        _saved = <String>{...preferences.labels};
        _editing = <String>{..._saved};
      });
    } catch (error) {
      if (!mounted) return;
      // A failed read must never be treated as an empty allergy profile.
      setState(() {
        _preferencesError = _friendlyError(
          error,
          fallback:
              'We couldn’t load your saved dietary settings. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  void _toggle(String key, bool selected) {
    if (_savingPreferences ||
        _loadingPreferences ||
        _preferencesError != null) {
      return;
    }

    setState(() {
      if (selected) {
        if (key == 'diet_vegan') _editing.remove('diet_vegetarian');
        if (key == 'diet_vegetarian') _editing.remove('diet_vegan');
        _editing.add(key);
      } else {
        _editing.remove(key);
      }
    });
  }

  Future<void> _savePreferences() async {
    if (!_canSave) return;

    setState(() {
      _savingPreferences = true;
      _dietaryFeedback = null;
    });

    try {
      final preferences = await DietaryPreferenceService.save(<String>{
        ..._editing,
      });
      if (!mounted) return;
      setState(() {
        _saved = <String>{...preferences.labels};
        _editing = <String>{..._saved};
        _dietaryFeedback = 'Your dietary settings have been saved and will be used by the AI Meal Assistant.';
        _dietaryFeedbackKind = _DietaryFeedbackKind.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dietaryFeedback = _friendlyError(
          error,
          fallback: 'We couldn’t save your dietary settings. Your selections are still here; please try again.',
        );
        _dietaryFeedbackKind = _DietaryFeedbackKind.error;
      });
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  Future<void> _requestLeave() async {
    if (_savingPreferences) return;
    if (!_dietaryDirty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Discard unsaved changes?'),
        content: const Text('Your last saved dietary settings will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (!mounted || discard != true || _savingPreferences) return;
    setState(() => _editing = <String>{..._saved});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _friendlyError(Object error, {required String fallback}) =>
      AppFeedback.fromError(error, fallback: fallback).message;

  Widget _feedbackBanner({
    required String title,
    required String message,
    required _DietaryFeedbackKind kind,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FeedbackBanner(
      feedback: FeedbackData(
        title: title,
        message: message,
        type: FeedbackType.values.byName(kind.name),
      ),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _sectionHeader(IconData icon, String title, String description) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _lightOrange,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _primary, size: 23),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _chipSection({
    required IconData icon,
    required String title,
    required String description,
    required Map<String, String> options,
  }) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(icon, title, description),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in options.entries)
              FilterChip(
                label: Text(option.value),
                selected: _editing.contains(option.key),
                onSelected: _savingPreferences
                    ? null
                    : (value) => _toggle(option.key, value),
                selectedColor: _lightOrange,
                backgroundColor: _paleOrange,
                checkmarkColor: _primary,
                labelStyle: const TextStyle(color: _charcoal, fontSize: 13),
                side: BorderSide(
                  color: _editing.contains(option.key) ? _primary : _border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _allergySection() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.health_and_safety_outlined,
          'Allergies & restrictions',
          'Select any known allergies or medically required restrictions you want FoodWise to remember.',
        ),
        const SizedBox(height: 10),
        for (final option in _allergies.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: _primary,
            title: Text(
              option.value,
              style: const TextStyle(color: _charcoal, fontSize: 14),
            ),
            value: _editing.contains(option.key),
            onChanged: _savingPreferences
                ? null
                : (value) => _toggle(option.key, value ?? false),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _paleOrange,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _primary, size: 20),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'FoodWise uses self-reported settings and seller-provided menu information. It cannot guarantee that a meal is allergy-safe. Always confirm ingredients and cross-contact with the seller.',
                  style: TextStyle(color: _charcoal, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dietaryContent() {
    if (_loadingPreferences) {
      return _panel(
        child: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_preferencesError != null) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedbackBanner(
              feedback: AppFeedback.failure(
                'Preferences could not load',
                _preferencesError!,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Editing is unavailable until your existing settings are loaded.',
            ),
            TextButton.icon(
              onPressed: _loadPreferences,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_dietaryFeedback != null) ...[
          _feedbackBanner(
            title: _dietaryFeedbackKind == _DietaryFeedbackKind.success
                ? 'Preferences saved'
                : 'We couldn’t save your preferences',
            message: _dietaryFeedback!,
            kind: _dietaryFeedbackKind,
          ),
          const SizedBox(height: 12),
        ],
        _chipSection(
          icon: Icons.favorite_border_rounded,
          title: 'Foods I like',
          description: 'Choose foods you enjoy.',
          options: _likedFoods,
        ),
        const SizedBox(height: 12),
        _chipSection(
          icon: Icons.eco_outlined,
          title: 'Eating pattern',
          description: 'Optional. Leave both unselected if neither applies.',
          options: _eatingPatterns,
        ),
        const SizedBox(height: 12),
        _chipSection(
          icon: Icons.no_food_outlined,
          title: 'Foods to avoid',
          description: 'Select foods you prefer not to eat. Use the allergy section for known allergies.',
          options: _avoidFoods,
        ),
        const SizedBox(height: 12),
        _allergySection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_dietaryDirty && !_savingPreferences,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_savingPreferences) _requestLeave();
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _charcoal,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Dietary Settings',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          leading: BackButton(onPressed: _requestLeave),
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                children: [
                  const Text(
                    'Personalize your meals',
                    style: TextStyle(
                      fontSize: 27,
                      color: _charcoal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tell FoodWise what you enjoy, what you avoid, and which allergies or restrictions the AI Meal Assistant should consider.',
                    style: TextStyle(color: _muted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  _dietaryContent(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar:
            _dietaryDirty && !_loadingPreferences && _preferencesError == null
            ? SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  decoration: const BoxDecoration(
                    color: _surface,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 724),
                      child: FilledButton.icon(
                        onPressed: _canSave ? _savePreferences : null,
                        icon: _savingPreferences
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          _savingPreferences
                              ? 'Saving dietary settings...'
                              : 'Save dietary settings',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
