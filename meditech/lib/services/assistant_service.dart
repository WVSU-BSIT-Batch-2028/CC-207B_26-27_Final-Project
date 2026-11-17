import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';

// Sends one question to the assistant function
abstract class AssistantService {
  Future<String> ask(String message);
}

class SupabaseAssistantService implements AssistantService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<String> ask(String message) async {
    try {
      final response = await _client.functions.invoke(
        'ai-assistant',
        body: {'message': message.trim()},
      );
      final data = response.data;
      if (data is Map && data['answer'] is String && (data['answer'] as String).isNotEmpty) {
        return data['answer'] as String;
      }
      throw const AppFailure('The assistant is unavailable.');
    } on FunctionException catch (error) {
      throw _failure(error);
    }
  }

  // Keep the function's own message, including the daily limit and unavailable text
  AppFailure _failure(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'];
      if (message is String && message.isNotEmpty) return AppFailure(message);
    }
    if (error.status == 0) return const AppFailure('Could not reach Supabase.');
    return const AppFailure('The assistant is unavailable.');
  }
}