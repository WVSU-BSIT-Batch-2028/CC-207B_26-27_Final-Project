import 'package:flutter/material.dart';

import '../theme/paper_theme.dart';
import 'paper_widgets.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.note, this.title, this.wide, {super.key});

  final String note;
  final String title;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(note, style: Paper.hand(30, color: Paper.tomato)),
        Scribble(
          kind: ScribbleKind.underline,
          color: Paper.cobalt,
          child: Text(title, style: Paper.display(wide ? 56 : 40)),
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.tab,
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    required this.cta,
    required this.angle,
    required this.onTap,
    super.key,
  });

  final String tab;
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final String cta;
  final double angle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      angle: angle,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Paper.ink, width: 1.6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: const [
                BoxShadow(color: Paper.ink, offset: Offset(5, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Paper.ink, width: 1.4),
                  ),
                  child: Icon(icon, color: Paper.ink),
                ),
                const SizedBox(height: 18),
                Text(title, style: Paper.display(26)),
                const SizedBox(height: 8),
                Text(text, style: Paper.body(15.5)),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cta.toUpperCase(), style: Paper.mono(12)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Paper.ink, width: 1.6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Text(tab, style: Paper.mono(11)),
            ),
          ),
        ],
      ),
    );
  }
}

class NavBar extends StatelessWidget {
  const NavBar({
    required this.labels,
    required this.wide,
    required this.onSelect,
    required this.onStaff,
    this.isStaff = true,
    this.userLabel,
    this.onLogout,
    super.key,
  });

  final List<String> labels;
  final bool wide;
  final ValueChanged<int> onSelect;
  final VoidCallback onStaff;
  final bool isStaff;
  final String? userLabel;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final logo = InkWell(
      onTap: () => onSelect(0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Paper.mustard,
              shape: BoxShape.circle,
              border: Border.all(color: Paper.ink, width: 1.4),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              size: 19,
              color: Paper.ink,
            ),
          ),
          const SizedBox(width: 10),
          Text('MatchBack', style: Paper.display(22)),
        ],
      ),
    );

    return Material(
      color: Paper.paper.withValues(alpha: 0.96),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Paper.ink, width: 1.4)),
        ),
        child: Row(
          children: [
            logo,
            if (wide) ...[
              const SizedBox(width: 32),
              for (var i = 0; i < labels.length; i++)
                TextButton(
                  onPressed: () => onSelect(i),
                  style: TextButton.styleFrom(
                    foregroundColor: Paper.ink,
                    overlayColor: Paper.mustard.withValues(alpha: 0.4),
                    textStyle: Paper.mono(12),
                  ),
                  child: Text(labels[i].toUpperCase()),
                ),
              const Spacer(),
              if (isStaff)
                OutlinedButton.icon(
                  onPressed: onStaff,
                  icon: const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 18,
                  ),
                  label: const Text('STAFF REVIEW'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Paper.ink,
                    side: const BorderSide(color: Paper.ink, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: Paper.mono(12),
                  ),
                ),
              if (userLabel != null && userLabel!.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text(userLabel!.toUpperCase(), style: Paper.mono(12)),
              ],
              if (onLogout != null)
                IconButton(
                  tooltip: 'Log out',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
            ] else ...[
              const Spacer(),
              PopupMenuButton<int>(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu_rounded),
                onSelected: (v) {
                  if (v == -1) {
                    onStaff();
                  } else if (v == -2) {
                    onLogout?.call();
                  } else {
                    onSelect(v);
                  }
                },
                itemBuilder: (_) => [
                  for (var i = 0; i < labels.length; i++)
                    PopupMenuItem(value: i, child: Text(labels[i])),
                  if (isStaff)
                    const PopupMenuItem(value: -1, child: Text('Staff Review')),
                  if (onLogout != null)
                    const PopupMenuItem(value: -2, child: Text('Log out')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
