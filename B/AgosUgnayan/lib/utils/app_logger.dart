// Small logging helper. It prints only in debug mode, so real error details
// help developers without ever being shown to users or printed in release.

import 'package:flutter/foundation.dart';

/// Logs messages and errors for developers. Search the console for "[AgosUgnayan]".
class AppLogger {
  AppLogger._();

  /// Logs a normal message, e.g. `AppLogger.info('[ListingService] saving')`.
  static void info(String message) {
    if (kDebugMode) debugPrint('[AgosUgnayan] $message');
  }

  /// Logs an error with the real exception and stack trace.
  static void error(String message, [Object? error, StackTrace? stack]) {
    if (!kDebugMode) return;
    debugPrint('[AgosUgnayan] ERROR: $message');
    if (error != null) debugPrint('  $error');
    if (stack != null) debugPrint('$stack');
  }
}
