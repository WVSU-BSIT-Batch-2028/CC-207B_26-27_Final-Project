import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/contact_details.dart';
import '../services/contact_storage.dart';
import '../theme/paper_theme.dart';

/// Staff-only box for a student's contact details. Nothing is fetched until
/// staff press the button, and Firestore rules allow only staff to read it.
class ContactReveal extends StatefulWidget {
  const ContactReveal({required this.kind, required this.refId, super.key});

  /// 'lost' for a lost report, 'claim' for a claim.
  final String kind;
  final String refId;

  @override
  State<ContactReveal> createState() => _ContactRevealState();
}

class _ContactRevealState extends State<ContactReveal> {
  bool _loading = false;
  bool _loaded = false;
  ContactDetails? _contact;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final contact = await ContactStorage.load(widget.kind, widget.refId);
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the contact details. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Copies one value so staff can paste it into an email or a phone app.
  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  /// One labelled line with a copy button. Empty values are not shown.
  Widget _row(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: Paper.mono(11)),
                SelectableText(value, style: Paper.body(15, color: Paper.ink)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copy(label, value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading...'),
        ],
      );
    }

    if (_loaded) {
      final contact = _contact;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Paper.mustard.withValues(alpha: 0.25),
          border: Border.all(color: Paper.ink, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: contact == null
            ? Text(
                'No contact details were saved. This report was made '
                'before contact details were collected.',
                style: Paper.body(15, color: Paper.ink),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Name', contact.fullName),
                  _row('Email', contact.email),
                  _row('Phone', contact.phone),
                ],
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.contact_phone_outlined),
          label: const Text('Show contact details'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        ],
      ],
    );
  }
}
