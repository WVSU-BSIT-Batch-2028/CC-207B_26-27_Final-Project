enum ChatRole { user, assistant }

/// How urgently the assistant suggests the person seeks care.
enum TriageLevel { selfCare, seeDoctor, urgent }

/// One bubble in the AI assistant conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.triage,
    this.isFallback = false,
    this.isSafety = false,
  });

  final int id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final TriageLevel? triage;

  /// True when the reply came from built-in rules (AI unavailable).
  final bool isFallback;

  /// True for the fixed emergency message (not written by the AI).
  final bool isSafety;
}

/// What an [AiAssistantService] returns.
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.triage,
    this.isFallback = false,
    this.isSafety = false,
  });

  final String text;
  final TriageLevel? triage;
  final bool isFallback;
  final bool isSafety;
}
