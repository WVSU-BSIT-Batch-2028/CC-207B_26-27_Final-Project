import 'package:final_project_look_out/app/themes/app_colors.dart';
import 'package:flutter/material.dart';

import 'dart:async';

enum NotifType { success, error, warning, info }

class PopupNotif {
  final String message;
  final String? title;
  final NotifType type;

  const PopupNotif({
    required this.message,
    this.title,
    this.type = NotifType.info,
  });

  Color _backgroundColor(ThemeData theme) => switch (type) {
    NotifType.success => AppColor.successGreen,
    NotifType.error => AppColor.errorRed,
    NotifType.warning => AppColor.warningYellow,
    NotifType.info => theme.colorScheme.inverseSurface,
  };

  IconData get _icon => switch (type) {
    NotifType.success => Icons.check_circle_outline,
    NotifType.error => Icons.error_outline,
    NotifType.warning => Icons.warning_amber_rounded,
    NotifType.info => Icons.info_outline,
  };

  void show(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = _backgroundColor(theme);
    final foregroundColor = theme.colorScheme.onInverseSurface;

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    Timer? timer;

    void dismiss() {
      timer?.cancel();

      if (entry.mounted) {
        entry.remove();
        entry.dispose();
      }
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 12,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_icon, color: foregroundColor, size: 24),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title!.isNotEmpty)
                          Text(
                            title!,
                            style: TextStyle(
                              color: foregroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                        Text(
                          message,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: dismiss,
                    icon: Icon(Icons.close, color: foregroundColor, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    timer = Timer(const Duration(seconds: 3), dismiss);
  }
}

