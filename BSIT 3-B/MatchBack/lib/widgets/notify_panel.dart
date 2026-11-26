import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/claim_request.dart';
import '../models/notification_record.dart';
import '../services/notification_storage.dart';
import '../theme/paper_theme.dart';
import '../utils/date_format.dart';
import '../utils/notification_text.dart';

/// Staff-only panel for an approved or ready claim: a message to copy, a
/// way to record that the student was contacted, and the log so far.
class NotifyPanel extends StatefulWidget {
  const NotifyPanel({required this.claim, super.key});

  final ClaimRequest claim;

  @override
  State<NotifyPanel> createState() => _NotifyPanelState();
}

class _NotifyPanelState extends State<NotifyPanel> {
  final _storage = NotificationStorage();
  late Future<List<NotificationRecord>> _logFuture;

  String _method = 'email';
  bool _saving = false;

  /// The message depends on the claim's current step.
  String get _event => widget.claim.status == 'ready' ? 'ready' : 'approved';

  @override
  void initState() {
    super.initState();
    _logFuture = _storage.loadForClaim(widget.claim.id);
  }

  Future<void> _copyMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Message copied.')));
  }

  Future<void> _record(String outcome) async {
    setState(() {
      _saving = true;
    });

    try {
      await _storage.record(
        claim: widget.claim,
        event: _event,
        method: _method,
        outcome: outcome,
      );

      if (!mounted) return;
      setState(() {
        _logFuture = _storage.loadForClaim(widget.claim.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact attempt recorded.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record this. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = buildNotificationMessage(
      event: _event,
      name: widget.claim.claimantName,
      itemName: widget.claim.foundItemName,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Paper.sky.withValues(alpha: 0.35),
        border: Border.all(color: Paper.ink, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTIFY THE STUDENT', style: Paper.mono(11)),
          const SizedBox(height: 6),
          const Text(
            'Copy the message and send it by email, phone call or text. Use '
            '"Show contact details" above to copy the email or number.',
          ),
          const SizedBox(height: 8),
          SelectableText(message, style: Paper.body(15, color: Paper.ink)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copyMessage(message),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy message'),
          ),
          const SizedBox(height: 12),
          Text('AFTER YOU CONTACT THE STUDENT', style: Paper.mono(11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _method,
                items: const [
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'phone', child: Text('Phone call')),
                  DropdownMenuItem(value: 'text', child: Text('Text message')),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _method = value;
                          });
                        }
                      },
              ),
              FilledButton(
                onPressed: _saving ? null : () => _record('contacted'),
                child: const Text('Mark as contacted'),
              ),
              OutlinedButton(
                onPressed: _saving ? null : () => _record('failed'),
                child: const Text('Could not reach'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('CONTACT LOG', style: Paper.mono(11)),
          const SizedBox(height: 6),
          FutureBuilder<List<NotificationRecord>>(
            future: _logFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return const Text('Could not load the contact log.');
              }

              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return const Text('No contact attempts recorded yet.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final record in records)
                    if (record.sentAt != null)
                      Text(
                        '${formatPhilippineTime(record.sentAt!)}: '
                        '${record.outcome == 'failed' ? 'Could not reach' : 'Contacted'} '
                        'by ${notificationMethodLabel(record.method)} '
                        '(${record.event == 'ready' ? 'ready for collection' : 'approval'})',
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
