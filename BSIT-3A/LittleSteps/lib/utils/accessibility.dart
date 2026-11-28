import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Announces [message] to active assistive technologies when a view is mounted.
void announceForAccessibility(BuildContext context, String message) {
  final view = View.maybeOf(context);
  if (view == null) return;
  try {
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  } catch (_) {}
}
