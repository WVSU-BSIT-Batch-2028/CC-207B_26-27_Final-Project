/// Thrown when the AI service is unavailable or returns something unusable.
/// The fallback wrapper catches it and shows offline guidance instead.
class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => 'AiServiceException: $message';
}
