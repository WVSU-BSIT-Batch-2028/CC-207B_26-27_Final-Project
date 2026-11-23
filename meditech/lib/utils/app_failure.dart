import 'package:supabase_flutter/supabase_flutter.dart';

import 'friendly_error.dart';

class AppFailure implements Exception {
  final String message;

  const AppFailure(this.message);

  factory AppFailure.fromPostgrest(PostgrestException error) {
    return AppFailure(friendlyErrorMessage(error));
  }

  factory AppFailure.fromUnknown(Object error) {
    if (error is AppFailure) return error;
    if (error is PostgrestException) return AppFailure.fromPostgrest(error);
    return AppFailure(friendlyErrorMessage(error));
  }

  
  factory AppFailure.signIn(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'];
      if (message is String && message.isNotEmpty) {
        return AppFailure(message);
      }
    }
    if (error.status == 0) {
      return const AppFailure('Could not reach Supabase.');
    }
    return const AppFailure('Sign-in failed. Try again.');
  }

  // Read an error message from an Edge Function
  factory AppFailure.fromEdge(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'];
      if (message is String && message.isNotEmpty) return AppFailure(message);
    }
    if (error.status == 0) return const AppFailure('Could not reach Supabase.');
    return const AppFailure('Could not reset the password. Try again.');
  }

  @override
  String toString() => message;
}
