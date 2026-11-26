/// Thrown when the AI is unavailable or replies with nothing usable.
/// The fallback wrapper catches it and shows offline guidance.
class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => 'AiServiceException: $message';
}
