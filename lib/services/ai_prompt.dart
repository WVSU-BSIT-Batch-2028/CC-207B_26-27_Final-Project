import '../models/chat_message.dart';
import 'ai_exceptions.dart';

// What we send to Gemini and how we read its answer.
// No Firebase code here, so it can be unit tested.

/// The rules the model always follows (system prompt).
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

/// Removes emails, PH mobile numbers and long ID numbers before text is
/// sent to the AI (Data Privacy Act, RA 10173).
String redactPersonalInfo(String text) => text
    .replaceAll(_email, '[removed]')
    .replaceAll(_phone, '[removed]')
    .replaceAll(_longNumber, '[removed]');

/// The text sent to Gemini: recent messages for context, then the new one.
String buildPrompt(String message, List<ChatMessage> history) {
  // Skip the welcome bubble (id 0) and the newest message (added below).
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

/// Turns the raw reply ("LEVEL: ..." line, then the answer) into an
/// [AssistantReply]. Unknown level -> see a doctor; no text -> throws.
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
