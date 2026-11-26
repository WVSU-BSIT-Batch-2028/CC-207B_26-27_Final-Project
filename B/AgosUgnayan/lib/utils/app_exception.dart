// The one error type that services throw to screens. It always carries a
// friendly message that is safe to show, never raw Firebase or Dart errors.
// runSafely() is the try/catch every service uses around Firebase calls.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'app_logger.dart';
import 'strings.dart';

/// Turns any error into text that is safe to show the user. An [AppException]
/// keeps its own message; anything else becomes the generic message.
String friendlyMessage(Object? error) {
  if (error is AppException) return error.message;
  return AppStrings.genericError;
}

/// An error with a message that can be shown to the user as-is.
class AppException implements Exception {
  const AppException(this.message);

  /// Friendly text from AppStrings, e.g. "Could not connect…".
  final String message;

  @override
  String toString() => message;
}

/// Runs a Firebase [action] with a 15 second timeout. If it fails, the real
/// error is logged for us and an [AppException] with a friendly message is
/// thrown for the screen. [what] names the action in the log, e.g.
/// "load listings".
Future<T> runSafely<T>(String what, Future<T> Function() action) async {
  try {
    return await action().timeout(const Duration(seconds: 15));
  } on AppException {
    rethrow; // already friendly
  } on TimeoutException {
    throw const AppException(AppStrings.timeoutError);
  } on FirebaseException catch (e, stack) {
    AppLogger.error('$what failed (${e.code})', e, stack);
    if (e.code == 'permission-denied') {
      throw const AppException(AppStrings.permissionError);
    }
    if (e.code == 'unavailable') {
      throw const AppException(AppStrings.networkError);
    }
    throw const AppException(AppStrings.genericError);
  } catch (e, stack) {
    AppLogger.error('$what failed', e, stack);
    throw const AppException(AppStrings.genericError);
  }
}
