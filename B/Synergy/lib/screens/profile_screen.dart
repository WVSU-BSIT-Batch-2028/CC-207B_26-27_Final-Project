import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
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
                            validator: (v) =>
                                _required(v, 'Describe what you can offer'),
                          ),
                          const SizedBox(height: 12),
                          TagEditor(
                            label: 'We offer',
                            selected: _offers,
                            onChanged: (tags) =>
                                setState(() => _offers = tags),
                            errorText: _triedSave && _offers.isEmpty
                                ? 'Pick at least one offer tag'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _needText,
                            decoration: const InputDecoration(
                              labelText: 'What do you need?',
                            ),
                            minLines: 2,
                            maxLines: 4,
                            validator: (v) =>
                                _required(v, 'Describe what you need'),
                          ),
                          const SizedBox(height: 12),
                          TagEditor(
                            label: 'We need',
                            selected: _needs,
                            onChanged: (tags) =>
                                setState(() => _needs = tags),
                            errorText: _triedSave && _needs.isEmpty
                                ? 'Pick at least one need tag'
                                : null,
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
