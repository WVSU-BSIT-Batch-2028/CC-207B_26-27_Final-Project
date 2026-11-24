import 'package:firebase_ai/firebase_ai.dart';

import '../models/chat_message.dart';
import 'ai_assistant_service.dart';
import 'ai_prompt.dart';

/// The real AI: sends the patient's message to Google's Gemini model through
/// Firebase AI Logic and returns the answer.
///
/// - Needs Firebase and App Check to be started (see FirebaseBootstrap). The factory
///   only uses this class when they are.
/// - Any failure (no internet, quota, blocked content, odd reply) is turned into
///   an [AiServiceException]. FallbackAiAssistantService then shows offline guidance.
/// - There is no Gemini key in the app: Firebase AI Logic is set up in the Firebase console.
class GeminiAssistantService implements AiAssistantService {
  /// The model. Firebase retires models over time (gemini-2.5-flash gives a 404 once it is
  /// shut down). If you get a 404 again, pick a current STABLE model from the Firebase
  /// AI Logic "supported models" page, for example `gemini-3.5-flash`.
  static const String modelName = 'gemini-3.1-flash-lite';

  GenerativeModel? _model;

  /// Created on first use, with our rules (system prompt) and settings.
  /// App Check is attached automatically once FirebaseBootstrap has activated it
  /// (current firebase_ai versions no longer take an appCheck argument).
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
    // Demo switch in the AI screen menu, to show the fallback live.
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
