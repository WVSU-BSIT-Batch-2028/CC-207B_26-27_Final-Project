import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../models.dart';
import '../rules.dart';

const testingWindows = ['3 days', '1 week', '2 weeks'];

// Terms form and who has agreed, inside a room
class TermsPanel extends StatefulWidget {
  const TermsPanel({super.key, required this.store, required this.exchange});

  final AppStore store;
  final Exchange exchange;

  @override
  State<TermsPanel> createState() => _TermsPanelState();
}

class _TermsPanelState extends State<TermsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _goal = TextEditingController();
  final _testerCount = TextEditingController();
  final _deliverables = TextEditingController();
  String _window = '1 week';
  bool _busy = false; // true while saving or agreeing
  String _loaded = ''; // the saved terms the fields were filled from

  Exchange get e => widget.exchange;

  // The saved terms as one string, to notice when they change
  String get _savedTerms =>
      '${e.goal}|${e.testerCount}|${e.testingWindow}|${e.deliverables}';

  @override
  void initState() {
    super.initState();
    _fillFromExchange();
  }

  @override
  void didUpdateWidget(TermsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Someone saved new terms, so show them
    if (_savedTerms != _loaded) _fillFromExchange();
  }

  void _fillFromExchange() {
    _goal.text = e.goal;
    _testerCount.text = e.testerCount > 0 ? '${e.testerCount}' : '';
    _deliverables.text = e.deliverables;
    _window = testingWindows.contains(e.testingWindow)
        ? e.testingWindow
        : '1 week';
    _loaded = _savedTerms;
  }

  @override
  void dispose() {
    _goal.dispose();
    _testerCount.dispose();
    _deliverables.dispose();
    super.dispose();
  }

  // Run a store action with the buttons off, and explain a refusal
  Future<void> _run(Future<bool> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await action();
    if (mounted) setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("That action isn't allowed anymore.")),
      );
    }
  }

  void _save(String me) {
    if (!_formKey.currentState!.validate()) return;
    _run(
      () => widget.store.saveTerms(
        e,
        me,
        _goal.text,
        int.parse(_testerCount.text),
        _window,
        _deliverables.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.store.currentId ?? '';
    final partnerId = e.senderId == me ? e.recipientId : e.senderId;
    final locked = Rules.termsLocked(e);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Terms', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),

              // Who has agreed to the current terms
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [_agreement(me), _agreement(partnerId)],
              ),
              if (locked) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.verified, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Terms agreed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _goal,
                enabled: !locked,
                decoration: const InputDecoration(
                  labelText: 'Goal',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a goal' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _testerCount,
                enabled: !locked,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Tester count',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                    ? null
                    : 'Enter at least 1 tester',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_loaded), // refresh when saved terms change
                initialValue: _window,
                decoration: const InputDecoration(
                  labelText: 'Testing window',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final w in testingWindows)
                    DropdownMenuItem(value: w, child: Text(w)),
                ],
                onChanged: locked
                    ? null // read-only once agreed
                    : (w) => setState(() => _window = w ?? '1 week'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deliverables,
                enabled: !locked,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Deliverables',
                  hintText: 'What each side will do',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the deliverables' : null,
              ),

              if (!locked) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : () => _save(me),
                      child: const Text('Save terms'),
                    ),
                    if (Rules.canAgreeTerms(e, me))
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => widget.store.agreeTerms(e, me)),
                        child: const Text('Agree to these terms'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Saving changes asks the other startup to agree again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // One startup's name with ✓ or "pending"
  Widget _agreement(String id) {
    final name = widget.store.startupById(id)?.name ?? 'Unknown startup';
    final agreed = e.termsAgreedBy.contains(id);
    return Text('$name ${agreed ? '✓' : '· pending'}');
  }
}
