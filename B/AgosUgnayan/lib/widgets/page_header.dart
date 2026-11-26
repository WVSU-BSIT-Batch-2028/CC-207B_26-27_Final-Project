// The heading at the top of every main page, like the website: a small green
// line (eyebrow), a big uppercase title, and an optional grey sentence.

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// e.g. "LEON, ILOILO" / "MY CROPS" / "What you are selling right now."
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.lead,
    this.trailing,
    this.help,
  });

  /// Big title. It is shown in capitals, so write it normally.
  final String title;

  /// Small green text above the title.
  final String? eyebrow;

  /// Grey sentence under the title.
  final String? lead;

  /// Optional widget on the right, e.g. an "Add crop" button.
  final Widget? trailing;

  /// Short tips for this page. When given, a "?" button next to the title
  /// opens them (Nielsen: help and documentation). One tip per line.
  final List<String>? help;

  @override
  Widget build(BuildContext context) {
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: AppTextStyles.eyebrow),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Flexible(
              child: Text(title.toUpperCase(), style: AppTextStyles.pageTitle),
            ),
            if (help != null)
              IconButton(
                tooltip: 'How this page works',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.help_outline,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    showHelpSheet(context, title: title, tips: help!),
              ),
          ],
        ),
        if (lead != null) ...[
          const SizedBox(height: 6),
          Text(lead!, style: AppTextStyles.lead),
        ],
      ],
    );
    if (trailing == null) return texts;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: texts),
        const SizedBox(width: AppSizes.small),
        trailing!,
      ],
    );
  }
}

/// A section heading inside a page, with an optional link on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.sectionTitle)),
        ?action,
      ],
    );
  }
}

/// A sheet from the bottom with a page's tips, each with a check mark.
Future<void> showHelpSheet(
  BuildContext context, {
  required String title,
  required List<String> tips,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How $title works',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.link,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tip, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
