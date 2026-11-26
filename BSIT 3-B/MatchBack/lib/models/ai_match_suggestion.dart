/// One possible match suggested by the AI: which found item, and why.
class AiMatchSuggestion {
  const AiMatchSuggestion({required this.candidateId, required this.reason});

  /// The ID of a found-item report (always checked against real reports).
  final String candidateId;

  /// Short explanation written by the AI.
  final String reason;
}
