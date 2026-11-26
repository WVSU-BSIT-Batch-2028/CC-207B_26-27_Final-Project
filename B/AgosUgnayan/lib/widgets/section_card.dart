// A white card with a title row on top ("Buyer demand for your crops",
// "See all") and its content below. Groups related information so each
// part of a page is easy to find (Gestalt: proximity and common region).

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Card with [title], an optional [action] link and [child] below.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
    this.padChild = true,
  });

  final String title;
  final IconData? icon;

  /// e.g. a "See all" TextButton on the right of the title.
  final Widget? action;

  final Widget child;

  /// False lets [child] (e.g. a list with dividers) reach the card's edges.
  final bool padChild;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.link),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
                ?action,
              ],
            ),
          ),
          if (padChild)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            )
          else
            child,
        ],
      ),
    );
  }
}
