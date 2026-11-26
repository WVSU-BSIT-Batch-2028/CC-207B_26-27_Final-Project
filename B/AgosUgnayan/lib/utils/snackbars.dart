// Helpers for the short message shown at the bottom after every action,
// e.g. "Listing saved". Keeps the look and timing the same everywhere.

import 'package:flutter/material.dart';

import 'strings.dart';
import 'theme.dart';

/// Shows a short success or info message.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows a friendly error message in red.
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dangerStrong),
    );
}

/// Shows a message with an Undo button, e.g. after deleting a listing.
/// [onUndo] runs only if the user taps Undo before the SnackBar closes.
void showUndoMessage(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: AppStrings.undo, onPressed: onUndo),
      ),
    );
}
