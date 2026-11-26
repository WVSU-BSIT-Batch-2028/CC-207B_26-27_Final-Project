import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../rules.dart';
import 'matches_screen.dart';

// One startup's details and a form to send it an introduction
class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.store,
    required this.startup,
  });

  final AppStore store;
  final Startup startup;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  static const maxNote = 280;

  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  bool _sending = false; // true while the invite saves

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? _checkNote(String? value) {
    final note = (value ?? '').trim();
    if (note.isEmpty) return 'Write a short note';
    if (note.length > maxNote) {
      return 'Keep it to $maxNote characters (now ${note.length})';
    }
    return null;
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    // Grab these before the await, the screen may close
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await widget.store.sendInvite(
      widget.store.currentId!,
      widget.startup.id,
      _note.text,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Introduction sent')),
      );
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.startup;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final me = widget.store.currentStartup!;
          final canSend = Rules.canSendInvite(
            me.id,
            s.id,
            widget.store.exchanges,
          );
          final isSaved = me.savedIds.contains(s.id);
          final stillNeed = Rules.theyStillNeed(me, s);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // About the startup
                  if (s.industry.isNotEmpty)
                    Text(s.industry, style: theme.textTheme.titleSmall),
                  if (s.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(s.description, style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 16),
                  TagRow(label: 'Offers', tags: s.offers),
                  const SizedBox(height: 8),
                  TagRow(label: 'Needs', tags: s.needs),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => widget.store.toggleSaved(s.id),
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(isSaved ? 'Saved' : 'Save'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Why this match: both directions and what is missing
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why this match',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${Rules.matchFit(me, s)}% tag fit',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'They offer you: '
                            '${tagList(Rules.theyOffer(me, s))}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You offer them: '
                            '${tagList(Rules.youOffer(me, s))}',
                          ),
                          if (stillNeed.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "They also need (you don't offer): "
                              '${stillNeed.join(', ')}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Introduction form
                  Text(
                    'Send an introduction',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _note,
                      enabled: canSend && !_sending,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: 'Note to ${s.name}',
                        hintText: 'Could your students test our signup?',
                        helperText: 'Up to $maxNote characters',
                        border: const OutlineInputBorder(),
                      ),
                      validator: _checkNote,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!canSend) ...[
                    Text(
                      'You already have an open exchange with ${s.name}.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: canSend && !_sending ? _send : null,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Send introduction'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
