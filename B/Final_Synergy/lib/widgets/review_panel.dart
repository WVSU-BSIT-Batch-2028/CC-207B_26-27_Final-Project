import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../rules.dart';

class ReviewPanel extends StatefulWidget {
  const ReviewPanel({super.key, required this.store, required this.exchange});

  final AppStore store;
  final Exchange exchange;

  @override
  State<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<ReviewPanel> {
  final _note = TextEditingController();
  int _rating = 0;
  bool _showRatingError = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _name(String id) => widget.store.startupById(id)?.name ?? id;

  Future<void> _submit(String me) async {
    if (_saving) return;
    if (_rating == 0) {
      setState(() => _showRatingError = true);
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await widget.store.submitReview(
        widget.exchange,
        me,
        _rating,
        _note.text.trim(),
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

  Widget? _visibleReview(String viewerId, String authorId) {
    final e = widget.exchange;
    if (!Rules.canSeeReview(e, viewerId, authorId)) return null;

    final rating = e.ratings[authorId]!;
    final note = e.reviewNotes[authorId] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_name(authorId), style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(star <= rating ? Icons.star : Icons.star_border),
          ],
        ),
        if (note.isNotEmpty) Text(note),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.store.currentId;
    final e = widget.exchange;
    if (me == null || !Rules.isParticipant(e, me)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: e.stage == 'launched' || e.stage == 'reviewed'
            ? _reviews(context, me)
            : const Text('Reviews open when the room is launched.'),
      ),
    );
  }

  Widget _reviews(BuildContext context, String me) {
    final e = widget.exchange;
    final partnerId = me == e.senderId ? e.recipientId : e.senderId;
    final partner = _name(partnerId);
    final partnerReview = _visibleReview(me, partnerId);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (Rules.hasReviewed(e, me))
          Text('Your review of $partner is submitted.')
        else if (e.stage == 'launched') ...[
          Wrap(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  tooltip: star == 1 ? '1 star' : '$star stars',
                  isSelected: star <= _rating,
                  icon: const Icon(Icons.star_border),
                  selectedIcon: const Icon(Icons.star),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _rating = star;
                          _showRatingError = false;
                        }),
                ),
            ],
          ),
          if (_showRatingError)
            Text(
              'Pick a rating first.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : () => _submit(me),
            child: const Text('Submit review'),
          ),
        ],
        const SizedBox(height: 12),
        if (partnerReview != null) ...[
          Text('Reviewed', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ?_visibleReview(me, me),
          const SizedBox(height: 8),
          partnerReview,
        ] else if (Rules.hasReviewed(e, partnerId))
          Text('$partner has submitted a review. Submit yours to see it.')
        else
          Text("Waiting for $partner's review."),
      ],
    );
  }
}
