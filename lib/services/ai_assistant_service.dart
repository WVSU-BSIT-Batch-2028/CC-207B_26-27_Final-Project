import 'dart:async';

import '../core/firebase/firebase_bootstrap.dart';
import '../models/chat_message.dart';
import 'ai_exceptions.dart';
import 'gemini_assistant_service.dart';

export 'ai_exceptions.dart';

/// Contract for the AI symptom / FAQ assistant.
///
/// The UI only depends on this interface, so the real model call (e.g.
/// Firebase AI Logic / Gemini, or a Cloud Function) can be dropped in later
/// without touching any screen.
///
/// SECURITY: never hard-code an API key. Read it at build time with
/// `--dart-define=AI_API_KEY=...` or keep it behind your own backend, and
/// keep it out of Git (see .gitignore).
abstract class AiAssistantService {
  Future<AssistantReply> ask(String message, List<ChatMessage> history);
}

/// Deterministic safety layer. Runs BEFORE any AI call so that emergencies
/// are never left to a model's judgement.
class SafetyChecker {
  SafetyChecker._();

  static const List<String> _emergencyTerms = [
    'chest pain',
    'difficulty breathing',
    'trouble breathing',
    'shortness of breath',
    "can't breathe",
    'cannot breathe',
    'unconscious',
    'seizure',
    'severe bleeding',
    'stroke',
    'overdose',
  ];

  static const List<String> _selfHarmTerms = [
    'suicide',
    'kill myself',
    'end my life',
    'hurt myself',
  ];

  static bool isEmergency(String text) {
    final t = text.toLowerCase();
    return _emergencyTerms.any(t.contains);
  }

  static bool isSelfHarm(String text) {
    final t = text.toLowerCase();
    return _selfHarmTerms.any(t.contains);
  }
}

class _Rule {
  const _Rule(this.keywords, this.triage, this.reply);
  final List<String> keywords;
  final TriageLevel triage;
  final String reply;
}

/// Simple keyword rules. Used as the offline fallback when the AI is unavailable,
/// and for the fixed emergency messages. Intentionally conservative: when unsure,
/// suggest a doctor. These replies are NOT written by AI, and are labelled that way.
class RuleBasedAssistant {
  RuleBasedAssistant._();

  static const String _offlinePrefix =
      "I can't reach the AI assistant right now, so here is basic guidance:\n\n";

  static const List<_Rule> _rules = [
    _Rule(
      ['refill', 'renew', 'prescription', 'medicine', 'medication'],
      TriageLevel.selfCare,
      'You can manage prescriptions in the Prescription tab: set reminders, '
          'check your history and request a refill before your supply runs out.',
    ),
    _Rule(
      ['book', 'appointment', 'schedule', 'reschedule', 'consultation'],
      TriageLevel.selfCare,
      'Open the Appointment tab to pick a date and time. Video consultations '
          'are held through Google Meet and the link appears in your appointment details.',
    ),
    _Rule(
      ['fever', 'high temperature'],
      TriageLevel.seeDoctor,
      'A fever that lasts more than 2 to 3 days, or goes above 39 °C, should be '
          'checked by a doctor. Meanwhile, rest, drink plenty of fluids and keep '
          'track of your temperature.',
    ),
    _Rule(
      ['headache', 'migraine'],
      TriageLevel.selfCare,
      'Rest in a quiet, dim room and drink water. If the headache is sudden and '
          'severe, keeps coming back, or lasts more than 3 days, book a consultation.',
    ),
    _Rule(
      ['cough', 'sore throat', 'runny nose', 'colds', 'cold'],
      TriageLevel.selfCare,
      'Rest, warm fluids and good hydration usually help mild cold symptoms. '
          'If it lasts longer than a week or you develop a high fever, see a doctor.',
    ),
    _Rule(
      ['stomach', 'vomit', 'diarrhea', 'nausea'],
      TriageLevel.seeDoctor,
      'Sip fluids often to avoid dehydration. If symptoms last more than a day, '
          'you cannot keep fluids down, or you feel very weak, please see a doctor.',
    ),
  ];

  /// Builds a reply for [message]. [isFallback] adds the offline notice.
  static AssistantReply respond(String message, {bool isFallback = true}) {
    final prefix = isFallback ? _offlinePrefix : '';

    // Fixed safety notices: always shown first, never left to the AI, and
    // labelled as safety guidance (not "AI-generated").
    if (SafetyChecker.isSelfHarm(message)) {
      return const AssistantReply(
        text: 'I am really sorry you are going through this. You deserve support '
            'right now. Please contact emergency services (911) or reach out to '
            'someone you trust immediately.',
        triage: TriageLevel.urgent,
        isSafety: true,
      );
    }

    if (SafetyChecker.isEmergency(message)) {
      return const AssistantReply(
        text: 'Your symptoms may need urgent care. Please call 911 or go to the '
            'nearest emergency room now. Do not wait for an appointment.',
        triage: TriageLevel.urgent,
        isSafety: true,
      );
    }

    final lower = message.toLowerCase();
    for (final rule in _rules) {
      if (rule.keywords.any(lower.contains)) {
        return AssistantReply(
          text: '$prefix${rule.reply}',
          triage: rule.triage,
          isFallback: isFallback,
        );
      }
    }

    return AssistantReply(
      text: "${prefix}I'm not sure I understood that, and I can't diagnose "
          'conditions. If your symptoms are worrying or keep going, please book '
          'a consultation so a doctor can check you.',
      triage: TriageLevel.seeDoctor,
      isFallback: isFallback,
    );
  }
}

/// Demo-only switch (AI screen menu > "Simulate AI outage") that makes the
/// real AI fail on purpose, so the fallback can be shown live.
class AiDemoSwitch {
  AiDemoSwitch._();
  static bool simulateOutage = false;
}

/// Used when Firebase is not set up on this computer. It always fails, so the
/// person sees offline guidance honestly labelled "not AI" (never fake AI).
class UnavailableAiAssistantService implements AiAssistantService {
  const UnavailableAiAssistantService();

  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async {
    throw const AiServiceException('Firebase is not configured on this device.');
  }
}

/// Wraps any [AiAssistantService] and guarantees the user always gets a
/// usable answer: on timeout, error or empty output it falls back to rules.
class FallbackAiAssistantService implements AiAssistantService {
  FallbackAiAssistantService({
    required this.primary,
    this.timeout = const Duration(seconds: 8),
  });

  final AiAssistantService primary;
  final Duration timeout;

  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async {
    // Safety first: emergencies never wait on the model.
    if (SafetyChecker.isEmergency(message) || SafetyChecker.isSelfHarm(message)) {
      return RuleBasedAssistant.respond(message);
    }

    try {
      final reply = await primary.ask(message, history).timeout(timeout);
      if (reply.text.trim().isEmpty) {
        throw const AiServiceException('Empty reply');
      }
      return reply;
    } on Exception {
      // Timeout, service error or unusable result -> rule-based guidance.
      return RuleBasedAssistant.respond(message);
    }
  }
}

/// One place to decide which implementation the app uses:
/// Gemini (through Firebase) when Firebase and App Check are running, otherwise offline guidance.
/// The wrapper adds the timeout and the fallback in both cases.
class AiAssistantFactory {
  AiAssistantFactory._();

  static AiAssistantService create() => FallbackAiAssistantService(
        primary: FirebaseBootstrap.isAiReady
            ? GeminiAssistantService()
            : const UnavailableAiAssistantService(),
        timeout: const Duration(seconds: 12),
      );
}
