// A small rounded label for a status, e.g. "Open" or "Closed". It always has
// text, so the meaning never depends on color alone (accessibility).

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// The kinds of status the app shows, each with its own colors.
enum StatusKind { open, answered, closed, removed, expired }

/// e.g. a light green "Open" pill.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.kind});

  final String label;
  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (kind) {
      StatusKind.open => (AppColors.primaryLight, AppColors.primaryDark),
      StatusKind.answered => (AppColors.infoLight, AppColors.info),
      StatusKind.closed => (AppColors.segmented, AppColors.textMuted),
      StatusKind.removed => (AppColors.dangerLight, AppColors.danger),
      StatusKind.expired => (AppColors.warningLight, AppColors.warningInk),
    };
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      // widthFactor: 1 makes the pill only as wide as its text. Without it
      // the pill stretches across the screen when it has room to grow.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
