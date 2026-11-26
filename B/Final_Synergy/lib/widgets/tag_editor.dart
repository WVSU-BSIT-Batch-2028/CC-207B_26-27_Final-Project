import 'package:flutter/material.dart';

import '../rules.dart';

// A label and one chip per tag. Tap a chip to pick or unpick it.
class TagEditor extends StatelessWidget {
  const TagEditor({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.errorText,
    this.suggestions = const [],
    this.onRemoveSuggestion,
    this.onApply,
    this.onIgnore,
  });

  final String label;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? errorText; // shown in red under the chips
  final List<String> suggestions;
  final ValueChanged<String>? onRemoveSuggestion;
  final ValueChanged<List<String>>? onApply;
  final VoidCallback? onIgnore;

  void _toggle(String tag, bool on) {
    // Keep the allTags order
    final next = [
      for (final t in allTags)
        if (t == tag ? on : selected.contains(t)) t,
    ];
    onChanged(next);
  }

  Widget _suggestionChip(String tag) {
    final remove = onRemoveSuggestion;
    final onDelete = remove == null ? null : () => remove(tag);
    return Semantics(
      label: onDelete == null ? tag : 'Remove $tag suggestion',
      button: onDelete != null,
      onTap: onDelete,
      excludeSemantics: true,
      child: InputChip(label: Text(tag), onDeleted: onDelete),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in allTags)
              FilterChip(
                label: Text(tag),
                selected: selected.contains(tag),
                onSelected: (on) => _toggle(tag, on),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        // Suggestions stay apart from the chips above until Apply
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('AI-generated suggestions', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in suggestions) _suggestionChip(tag)],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: onApply == null ? null : () => onApply!(suggestions),
                child: const Text('Apply'),
              ),
              TextButton(onPressed: onIgnore, child: const Text('Ignore')),
            ],
          ),
        ],
      ],
    );
  }
}
