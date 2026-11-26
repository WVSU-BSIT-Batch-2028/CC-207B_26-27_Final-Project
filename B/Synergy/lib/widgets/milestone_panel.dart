import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../rules.dart';

class MilestonePanel extends StatefulWidget {
  const MilestonePanel({
    super.key,
    required this.store,
    required this.exchange,
  });

  final AppStore store;
  final Exchange exchange;

  @override
  State<MilestonePanel> createState() => _MilestonePanelState();
}

class _MilestonePanelState extends State<MilestonePanel> {
  final _note = TextEditingController();
  bool _saving = false;

  Exchange get _exchange => widget.exchange;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _name(String id) => widget.store.startupById(id)?.name ?? id;

  Future<void> _check(int step, String me) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.store.confirmStep(
        _exchange,
        step,
        me,
        note: _note.text,
      );
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That action isn't allowed anymore.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _exchange;
    final progress = Rules.progress(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: !Rules.termsLocked(e)
            ? const Text(
                'Milestones open after both startups agree to the terms.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progress $progress/2'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress / 2),
                  const SizedBox(height: 16),
                  _step(1, 'Testers assigned'),
                  const Divider(height: 24),
                  _step(2, 'Feedback submitted'),
                  if (e.stage == 'launched') ...[
                    const SizedBox(height: 12),
                    const Text('Launched'),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _step(int step, String title) {
    final e = _exchange;
    final confirmed = Rules.confirmedBy(e, step);
    final me = widget.store.currentId;
    final partner = me == e.senderId ? e.recipientId : e.senderId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$step · $title', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final id in [e.senderId, e.recipientId])
              Text('${_name(id)} ${confirmed.contains(id) ? '✓' : '—'}'),
          ],
        ),
        if (step == 2) ...[
          const SizedBox(height: 8),
          if (!Rules.stepDone(e, 1))
            const Text('Unlocks after both confirm step 1.'),
          if (e.feedbackNote.isNotEmpty)
            Text(e.feedbackNote)
          else
            TextFormField(
              controller: _note,
              enabled:
                  !_saving && Rules.stepDone(e, 1) && e.stage != 'launched',
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Feedback note',
                helperText: 'Required for the first confirmation',
                hintText: 'Three testers finished signup. Two missed the Continue button.',
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
        if (me != null &&
            confirmed.contains(me) &&
            !confirmed.contains(partner))
          Text('Waiting on ${_name(partner)}'),
        if (me != null && Rules.canConfirmStep(e, step, me, _note.text))
          FilledButton(
            onPressed: _saving ? null : () => _check(step, me),
            child: const Text('Check'),
          ),
      ],
    );
  }
}
