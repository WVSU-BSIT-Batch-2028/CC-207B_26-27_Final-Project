import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/chat_message.dart';
import 'package:health360/services/ai_exceptions.dart';
import 'package:health360/services/ai_prompt.dart';

void main() {
  group('redactPersonalInfo', () {
    test('removes emails and Philippine mobile numbers', () {
      final cleaned = redactPersonalInfo('Email me at ana@example.com or call 09123456789 or +63 912 345 6789.');
      expect(cleaned, isNot(contains('ana@example.com')));
      expect(cleaned, isNot(contains('09123456789')));
      expect(cleaned, isNot(contains('912 345 6789')));
      expect(cleaned, contains('[removed]'));
    });

    test('removes long ID-like numbers but keeps health numbers', () {
      final cleaned = redactPersonalInfo('My ID is 123456789012 and my blood pressure is 120/80.');
      expect(cleaned, isNot(contains('123456789012')));
      expect(cleaned, contains('120/80'));
    });
  });

  group('parseAssistantReply', () {
    test('reads the level and the answer', () {
      final reply = parseAssistantReply('LEVEL: URGENT\nCall 911 now.');
      expect(reply.triage, TriageLevel.urgent);
      expect(reply.text, 'Call 911 now.');
    });

    test('reads SELF_CARE and SEE_DOCTOR', () {
      expect(parseAssistantReply('LEVEL: SELF_CARE\nRest and drink water.').triage, TriageLevel.selfCare);
      expect(parseAssistantReply('LEVEL: SEE_DOCTOR\nPlease book a visit.').triage, TriageLevel.seeDoctor);
    });

    test('missing or unknown level becomes SEE_DOCTOR (the cautious choice)', () {
      expect(parseAssistantReply('Rest and drink water.').triage, TriageLevel.seeDoctor);
      expect(parseAssistantReply('LEVEL: MAYBE\nNot sure.').triage, TriageLevel.seeDoctor);
    });

    test('removes markdown bold markers', () {
      expect(parseAssistantReply('LEVEL: SELF_CARE\nDrink **water**.').text, 'Drink water.');
    });

    test('a reply with no text throws so the fallback is used', () {
      expect(() => parseAssistantReply('LEVEL: SELF_CARE'), throwsA(isA<AiServiceException>()));
    });
  });

  group('buildPrompt', () {
    ChatMessage msg(int id, ChatRole role, String text) =>
        ChatMessage(id: id, role: role, text: text, createdAt: DateTime(2026, 1, 1));

    test('includes earlier messages, removes personal info, and ends with the latest message', () {
      final history = [
        msg(0, ChatRole.assistant, 'Welcome'),
        msg(1, ChatRole.user, 'I have a cough, text me at 09123456789'),
        msg(2, ChatRole.assistant, 'How long has it lasted?'),
        msg(3, ChatRole.user, 'About 3 days'),
      ];
      final prompt = buildPrompt('About 3 days', history);
      expect(prompt, contains('Conversation so far:'));
      expect(prompt, contains('cough'));
      expect(prompt, isNot(contains('09123456789')));
      expect(prompt, isNot(contains('Welcome')));
      expect(prompt.trimRight().endsWith('About 3 days'), isTrue);
    });
  });
}
