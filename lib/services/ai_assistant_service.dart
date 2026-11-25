import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/firebase/firebase_bootstrap.dart';
import '../models/chat_message.dart';
import 'ai_exceptions.dart';
import 'gemini_assistant_service.dart';

export 'ai_exceptions.dart';

/// What the AI screen talks to, so the model behind it can change freely.
abstract class AiAssistantService {
  Future<AssistantReply> ask(String message, List<ChatMessage> history);
}

/// Keyword check that runs before any AI call, so emergencies never
/// depend on the model.
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

/// One offline rule: keywords, triage level and the reply.
class _Rule {
  const _Rule(this.keywords, this.triage, this.reply);
  final List<String> keywords;
  final TriageLevel triage;
  final String reply;
}

/// Keyword-based offline guidance, used when the AI cannot be reached.
/// Cautious on purpose and labelled "not AI" in the chat.
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

    // Fixed safety messages always come first.
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

/// Demo switch (AI menu > "Simulate AI outage") to show the fallback live.
class AiDemoSwitch {
  AiDemoSwitch._();
  static bool simulateOutage = false;
}

/// Used when Firebase is not set up: always fails, so offline guidance shows.
class UnavailableAiAssistantService implements AiAssistantService {
  const UnavailableAiAssistantService();

  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async {
    throw const AiServiceException('Firebase is not configured on this device.');
  }
}

/// Wraps the AI so the user always gets an answer: a failed or slow
/// attempt is retried, then offline guidance is used. Each failure is
/// printed in the browser console (F12).
class FallbackAiAssistantService implements AiAssistantService {
  FallbackAiAssistantService({
    required this.primary,
    this.timeout = const Duration(seconds: 8),
    this.retryDelays = const [Duration(seconds: 1), Duration(seconds: 2)],
    this.maxTotal = const Duration(seconds: 30),
  });

  final AiAssistantService primary;

  /// Time allowed for one attempt.
  final Duration timeout;

  /// Wait before each retry (its length = number of retries).
  final List<Duration> retryDelays;

  /// No new attempt starts after this, so the wait stays short.
  final Duration maxTotal;

  @override
  Future<AssistantReply> ask(String message, List<ChatMessage> history) async {
    // Safety first: emergencies never wait on the model.
    if (SafetyChecker.isEmergency(message) || SafetyChecker.isSelfHarm(message)) {
      return RuleBasedAssistant.respond(message);
    }

    final clock = Stopwatch()..start();
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      if (attempt > 0) {
        if (clock.elapsed + retryDelays[attempt - 1] >= maxTotal) break;
        await Future<void>.delayed(retryDelays[attempt - 1]);
      }
      try {
        final reply = await primary.ask(message, history).timeout(timeout);
        if (reply.text.trim().isEmpty) {
          throw const AiServiceException('Empty reply');
        }
        return reply;
      } on Exception catch (e) {
        debugPrint('AI attempt ${attempt + 1} failed: $e');
        // These never fix themselves, so do not retry.
        if (AiDemoSwitch.simulateOutage || primary is UnavailableAiAssistantService) break;
      }
    }
    // Still failing after the retries -> rule-based guidance.
    return RuleBasedAssistant.respond(message);
  }
}

/// Picks Gemini when Firebase and App Check are ready, otherwise offline
/// guidance, both wrapped with retries and fallback.
class AiAssistantFactory {
  AiAssistantFactory._();

  static AiAssistantService create() => FallbackAiAssistantService(
        primary: FirebaseBootstrap.isAiReady
            ? GeminiAssistantService()
            : const UnavailableAiAssistantService(),
        timeout: const Duration(seconds: 15),
      );
}
