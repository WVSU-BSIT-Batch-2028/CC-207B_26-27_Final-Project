import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../rules.dart';
import '../tag_ai.dart';
import '../widgets/demo_controls.dart';
import '../widgets/tag_editor.dart';

// The My startup page: edit the signed-in startup's profile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const stages = ['Idea', 'Prototype', 'Pilot', 'Launched', 'Growing'];

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController();
  late final _description = TextEditingController();
  late final _industry = TextEditingController();
  late final _teamSize = TextEditingController();
  late final _offerText = TextEditingController();
  late final _needText = TextEditingController();
  String? _stage;
  List<String> _offers = [];
  List<String> _needs = [];
  final _suggestions = <TextEditingController, List<String>>{};
  final _suggestionRequests = <TextEditingController, Future<List<String>>>{};
  final _loading = <TextEditingController>{}; // boxes waiting on the AI
  final _noTags = <TextEditingController>{}; // boxes where the AI found nothing
  bool _triedSave = false; // show tag errors only after Save

  @override
  void initState() {
    super.initState();
    // Start the form with the saved profile
    final s = widget.store.currentStartup!;
    _name.text = s.name;
    _description.text = s.description;
    _industry.text = s.industry;
    _teamSize.text = '${s.teamSize}';
    _offerText.text = s.offerText;
    _needText.text = s.needText;
    _stage = stages.contains(s.stage) ? s.stage : null; // unknown = pick again
    _offers = [...s.offers];
    _needs = [...s.needs];
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _industry,
      _teamSize,
      _offerText,
      _needText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  String? _checkTeamSize(String? value) {
    final size = int.tryParse((value ?? '').trim());
    if (size == null || size <= 0) return 'Team size must be above 0';
    return null;
  }

  // Ask the AI for tags, with a loading state and a 10-second limit
  Future<void> _suggest(TextEditingController field) async {
    final request = suggestTags(
      field.text,
    ).timeout(const Duration(seconds: 10));
    _suggestionRequests[field] = request;
    setState(() {
      _loading.add(field);
      _noTags.remove(field);
      _suggestions.remove(field);
    });
    var tags = <String>[];
    try {
      tags = await request;
    } catch (_) {
      // Error or timeout: treat as no tags
    } finally {
      if (mounted) setState(() => _loading.remove(field)); // button back on
    }
    // Skip old results, e.g. the founder typed while it ran
    if (!mounted || _suggestionRequests[field] != request) return;
    _suggestionRequests.remove(field);
    setState(() {
      if (tags.isEmpty) {
        _noTags.add(field);
      } else {
        _suggestions[field] = tags;
      }
    });
  }

  // Suggest tags button plus its loading or "no tags" text
  Widget _suggestRow(TextEditingController field, {bool privacyNote = false}) {
    final loading = _loading.contains(field);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Rebuild as the founder types so the button turns on and off
    final row = ValueListenableBuilder<TextEditingValue>(
      valueListenable: field,
      builder: (context, value, _) {
        final hasText = splitPieces(value.text).isNotEmpty;
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: loading || !hasText ? null : () => _suggest(field),
              child: const Text('Suggest tags'),
            ),
            if (loading) ...[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              Text('Reading your description…', style: muted),
            ] else if (!hasText)
              Text('Write a description first.', style: muted)
            else if (_noTags.contains(field))
              Text('No tags found. Choose them manually.', style: muted),
          ],
        );
      },
    );
    if (!privacyNote) return row;
    // Privacy: the model runs in the browser
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 4),
        Text(
          'The AI runs in your browser. Your text stays on this laptop.',
          style: muted,
        ),
      ],
    );
  }

  // x on a suggestion: drop it from the suggestions only
  void _removeSuggestion(TextEditingController field, String tag) {
    setState(() {
      _suggestions[field] = [
        for (final t in _suggestions[field] ?? const <String>[])
          if (t != tag) t,
      ];
    });
  }

  // Selected tags plus the applied ones, no duplicates, in chip order
  List<String> _merge(List<String> selected, List<String> applied) => [
    for (final t in allTags)
      if (selected.contains(t) || applied.contains(t)) t,
  ];

  // Ignore, Apply and typing all clear the suggestions row
  void _clearSuggestions(TextEditingController field, {VoidCallback? apply}) {
    _suggestionRequests.remove(field);
    final shown = _suggestions.containsKey(field) || _noTags.contains(field);
    if (!shown && apply == null) return;
    setState(() {
      _suggestions.remove(field);
      _noTags.remove(field);
      apply?.call();
    });
  }

  // Save writes the selected tags only, never the suggestions
  Future<void> _save() async {
    setState(() => _triedSave = true);
    final fieldsOk = _formKey.currentState!.validate();
    if (!fieldsOk || _offers.isEmpty || _needs.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final s = widget.store.currentStartup!;
    await widget.store.update(() {
      s.name = _name.text.trim();
      s.description = _description.text.trim();
      s.industry = _industry.text.trim();
      s.stage = _stage!;
      s.teamSize = int.parse(_teamSize.text.trim());
      s.offerText = _offerText.text.trim();
      s.needText = _needText.text.trim();
      s.offers = [..._offers];
      s.needs = [..._needs];
    });
    messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'My startup',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          gap,
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            validator: (v) => _required(v, 'Enter a name'),
                          ),
                          gap,
                          TextFormField(
                            controller: _description,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                            ),
                            minLines: 2,
                            maxLines: 4,
                          ),
                          gap,
                          TextFormField(
                            controller: _industry,
                            decoration: const InputDecoration(
                              labelText: 'Industry',
                            ),
                            validator: (v) =>
                                _required(v, 'Enter an industry'),
                          ),
                          gap,
                          DropdownButtonFormField<String>(
                            initialValue: _stage,
                            decoration: const InputDecoration(
                              labelText: 'Stage',
                            ),
                            items: [
                              for (final st in stages)
                                DropdownMenuItem(value: st, child: Text(st)),
                            ],
                            onChanged: (v) => setState(() => _stage = v),
                            validator: (v) =>
                                v == null ? 'Choose a stage' : null,
                          ),
                          gap,
                          TextFormField(
                            controller: _teamSize,
                            decoration: const InputDecoration(
                              labelText: 'Team size',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: _checkTeamSize,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _offerText,
                            decoration: const InputDecoration(
                              labelText: 'What can you offer?',
                            ),
                            minLines: 2,
                            maxLines: 4,
                            onChanged: (_) => _clearSuggestions(_offerText),
                            validator: (v) =>
                                _required(v, 'Describe what you can offer'),
                          ),
                          _suggestRow(_offerText, privacyNote: true),
                          const SizedBox(height: 12),
                          TagEditor(
                            label: 'We offer',
                            selected: _offers,
                            onChanged: (tags) =>
                                setState(() => _offers = tags),
                            errorText: _triedSave && _offers.isEmpty
                                ? 'Pick at least one offer tag'
                                : null,
                            suggestions: _suggestions[_offerText] ?? const [],
                            onRemoveSuggestion: (tag) =>
                                _removeSuggestion(_offerText, tag),
                            onApply: (tags) => _clearSuggestions(
                              _offerText,
                              apply: () => _offers = _merge(_offers, tags),
                            ),
                            onIgnore: () => _clearSuggestions(_offerText),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _needText,
                            decoration: const InputDecoration(
                              labelText: 'What do you need?',
                            ),
                            minLines: 2,
                            maxLines: 4,
                            onChanged: (_) => _clearSuggestions(_needText),
                            validator: (v) =>
                                _required(v, 'Describe what you need'),
                          ),
                          _suggestRow(_needText),
                          const SizedBox(height: 12),
                          TagEditor(
                            label: 'We need',
                            selected: _needs,
                            onChanged: (tags) =>
                                setState(() => _needs = tags),
                            errorText: _triedSave && _needs.isEmpty
                                ? 'Pick at least one need tag'
                                : null,
                            suggestions: _suggestions[_needText] ?? const [],
                            onRemoveSuggestion: (tag) =>
                                _removeSuggestion(_needText, tag),
                            onApply: (tags) => _clearSuggestions(
                              _needText,
                              apply: () => _needs = _merge(_needs, tags),
                            ),
                            onIgnore: () => _clearSuggestions(_needText),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                gap,
                DemoControls(store: widget.store),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
