import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';

class FeedbackBanner extends StatelessWidget {
  final FeedbackData feedback;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool actionLoading;
  const FeedbackBanner({
    super.key,
    required this.feedback,
    this.onAction,
    this.onDismiss,
    this.actionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = feedback.color;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: .06), Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(feedback.icon, color: color, size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback.message,
                    style: TextStyle(color: color, fontSize: 13, height: 1.45),
                  ),
                  if (feedback.actionLabel != null &&
                      (onAction != null || actionLoading))
                    TextButton.icon(
                      onPressed: actionLoading ? null : onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        padding: EdgeInsets.zero,
                      ),
                      icon: actionLoading
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: color,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(
                        actionLoading ? 'Please wait…' : feedback.actionLabel!,
                      ),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss message',
                icon: Icon(Icons.close_rounded, color: color, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
