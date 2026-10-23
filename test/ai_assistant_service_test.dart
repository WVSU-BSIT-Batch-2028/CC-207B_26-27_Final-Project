import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/chat_message.dart';
import 'package:health360/services/ai_assistant_service.dart';

/// Always fails, to prove the fallback kicks in.
class _FailingService implements AiAssistantService {
  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async =>
      throw const AiServiceException('boom');
}

/// Never answers in time, to prove the timeout kicks in.
class _SlowService implements AiAssistantService {
  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const AssistantReply(text: 'too late');
  }
}

void main() {
  test('emergency symptoms are always marked urgent', () {
    final reply = RuleBasedAssistant.respond('I have chest pain', isFallback: false);
    expect(reply.triage, TriageLevel.urgent);
    expect(reply.text, contains('911'));
  });

  test('fallback is used when the AI service errors', () async {
    final service = FallbackAiAssistantService(primary: _FailingService());
    final reply = await service.ask('I have a headache', const []);
    expect(reply.isFallback, isTrue);
    expect(reply.text, isNotEmpty);
  });

  test('fallback is used when the AI service times out', () async {
    final service = FallbackAiAssistantService(
      primary: _SlowService(),
      timeout: const Duration(milliseconds: 50),
    );
    final reply = await service.ask('cough for days', const []);
    expect(reply.isFallback, isTrue);
  });

  test('emergencies skip the model entirely', () async {
    final service = FallbackAiAssistantService(primary: _FailingService());
    final reply = await service.ask('severe bleeding', const []);
    expect(reply.triage, TriageLevel.urgent);
    expect(reply.isFallback, isFalse);
  });
}
