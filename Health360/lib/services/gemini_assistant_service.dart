import 'package:firebase_ai/firebase_ai.dart';

import '../models/chat_message.dart';
import 'ai_assistant_service.dart';
import 'ai_prompt.dart';

/// The real AI: sends the message to Gemini through Firebase AI Logic.
/// Any failure becomes an [AiServiceException]. No API key is in the app.
class GeminiAssistantService implements AiAssistantService {
  /// Firebase retires old models (a 404 means pick a current stable one).
  static const String modelName = 'gemini-3.1-flash-lite';

  GenerativeModel? _model;

  /// Created on first use with the system prompt. App Check is attached
  /// automatically once FirebaseBootstrap has activated it.
  GenerativeModel _getModel() {
    return _model ??= FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.text(assistantSystemPrompt),
      generationConfig: GenerationConfig(
        maxOutputTokens: 1024, // room for the answer (some models also "think" first)
        temperature: 0.4, // lower = more consistent, less creative
      ),
    );
  }

  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async {
    // Demo: fail on purpose to show the fallback.
    if (AiDemoSwitch.simulateOutage) {
      throw const AiServiceException('Simulated outage (demo).');
    }

    try {
      final prompt = buildPrompt(message, history); // personal details removed here
      final response = await _getModel().generateContent([Content.text(prompt)]);

      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) {
        throw const AiServiceException('Gemini returned no text.');
      }
      return parseAssistantReply(raw);
    } on AiServiceException {
      rethrow;
    } catch (e) {
      throw AiServiceException('Gemini request failed: $e');
    }
  }
}
