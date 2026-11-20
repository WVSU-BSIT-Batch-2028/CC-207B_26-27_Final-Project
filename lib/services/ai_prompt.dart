import '../models/chat_message.dart';
import 'ai_exceptions.dart';

/// Everything about WHAT we ask Gemini and HOW we read its answer.
/// Kept free of Firebase code so it can be unit-tested and explained easily.

/// The instructions the model always follows (the "system prompt").
const String assistantSystemPrompt = '''
You are the Health360 Assistant, a general health information helper inside a student clinic app in the Philippines.

Rules:
- You are not a doctor. Do not diagnose, do not name a disease as a conclusion, and do not prescribe medicines or doses.
- Give short, plain-English guidance in at most 5 sentences. Be calm and friendly.
- Start your answer with one line in exactly this form: LEVEL: SELF_CARE or LEVEL: SEE_DOCTOR or LEVEL: URGENT
- Use URGENT for possible emergencies (chest pain, trouble breathing, severe bleeding, signs of a stroke, thoughts of self-harm). Tell the person to call 911 or go to the nearest emergency room.
- Use SEE_DOCTOR when symptoms are persistent, getting worse, severe, or you are unsure.
- Use SELF_CARE only for mild, common symptoms, and say when to book a consultation.
- Questions about the app: appointments are booked in the Appointment tab, prescriptions and refills in the Prescription tab, results in Records, and video visits happen in Google Meet.
- If the question is not about health or this app, politely say you can only help with health questions and the app.
- Never ask for or repeat names, ID numbers, addresses or phone numbers.
- Do not use markdown, bullet points or headings. Plain sentences only.
''';

final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final RegExp _phone = RegExp(r'(\+?63|0)\s?9\d{2}[\s-]?\d{3}[\s-]?\d{4}');
final RegExp _longNumber = RegExp(r'\b\d{9,}\b');

/// Data minimisation (Data Privacy Act of 2012, RA 10173): removes emails,
/// Philippine mobile numbers and long ID-like numbers BEFORE text is sent to the AI.
String redactPersonalInfo(String text) => text
    .replaceAll(_email, '[removed]')
    .replaceAll(_phone, '[removed]')
    .replaceAll(_longNumber, '[removed]');

/// Builds the text sent to Gemini: the last few messages for context, then the
/// new message. Personal details are removed from every line.
String buildPrompt(String message, List<ChatMessage> history) {
  // Skip the welcome bubble (id 0). The newest user message is added below, so drop it here.
  final previous = history.where((m) => m.id != 0).toList();
  if (previous.isNotEmpty && previous.last.role == ChatRole.user) previous.removeLast();
  final recent = previous.length > 6 ? previous.sublist(previous.length - 6) : previous;

  final buffer = StringBuffer();
  if (recent.isNotEmpty) {
    buffer.writeln('Conversation so far:');
    for (final m in recent) {
      final who = m.role == ChatRole.user ? 'User' : 'Assistant';
      buffer.writeln('$who: ${redactPersonalInfo(m.text)}');
    }
    buffer.writeln();
  }
  buffer.writeln('Latest message from the user:');
  buffer.write(redactPersonalInfo(message));
  return buffer.toString();
}

/// Turns the model's raw text into an [AssistantReply].
/// Expected format: first line "LEVEL: ...", then the answer.
/// If the level is missing or unknown we choose SEE_DOCTOR (the cautious option).
/// If there is no answer text we throw, so the fallback guidance is shown.
AssistantReply parseAssistantReply(String raw) {
  TriageLevel? level;
  final body = <String>[];

  for (final line in raw.trim().split('\n')) {
    final trimmed = line.trim();
    if (level == null && trimmed.toUpperCase().startsWith('LEVEL:')) {
      final value = trimmed.substring(6).trim().toUpperCase();
      if (value.startsWith('URGENT')) {
        level = TriageLevel.urgent;
      } else if (value.startsWith('SELF')) {
        level = TriageLevel.selfCare;
      } else {
        level = TriageLevel.seeDoctor;
      }
      continue;
    }
    body.add(line);
  }

  final text = body.join('\n').replaceAll('**', '').trim();
  if (text.isEmpty) throw const AiServiceException('The reply had no text.');
  return AssistantReply(text: text, triage: level ?? TriageLevel.seeDoctor);
}
