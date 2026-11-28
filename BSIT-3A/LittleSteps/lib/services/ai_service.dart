import '../models/recommendation.dart';
import '../utils/domain_labels.dart';
import 'api_client.dart';

/// Client service for requesting AI play recommendations and story activities.
class AiService {
  /// Creates an [AiService] backed by [apiClient].
  AiService({required this.apiClient});

  /// HTTP client used to send authenticated requests to the backend API.
  final ApiClient apiClient;

  /// Requests play suggestions for [ageBand], [setting], [timeMinutes], and [materials].
  ///
  /// Sends only non-identifying play context so child names and private notes
  /// never leave the device in AI prompts.
  Future<RecommendationResponse> getRecommendations({
    required String ageBand,
    String? domain,
    String setting = PlaySetting.either,
    int timeMinutes = 15,
    List<String> materials = const [],
    String language = AppLanguages.english,
    int count = 3,
    bool allowCustom = true,
  }) async {
    final body = <String, dynamic>{
      'ageBand': ageBand,
      'setting': setting,
      'timeMinutes': timeMinutes,
      'materials': materials,
      'language': language,
      'count': count,
      'allowCustom': allowCustom,
    };
    if (domain != null) {
      body['domain'] = domain;
    }

    final data = await apiClient.post(
      '/api/v1/ai/recommendations',
      body: body,
    ) as Map<String, dynamic>;

    return RecommendationResponse.fromJson(data);
  }

  /// Requests companion activity ideas for a storybook.
  Future<Map<String, dynamic>> getStoryActivity({
    required String bookTitle,
    List<String> subjects = const [],
    required String ageBand,
  }) async {
    final body = {
      'bookTitle': bookTitle,
      'subjects': subjects,
      'ageBand': ageBand,
    };

    final data = await apiClient.post(
      '/api/v1/ai/story-activity',
      body: body,
    ) as Map<String, dynamic>;

    return data;
  }

  /// Requests an adapted variation of catalog activity [activityId] for [adjustment].
  ///
  /// Uses `POST /api/v1/ai/adapt` with optional [missingMaterial] and [ageBand],
  /// returning either a Tier 1 AI adaptation or a Tier 2 rule-based fallback.
  Future<AdaptActivityResponse> adaptActivity({
    required String activityId,
    required String adjustment,
    String? missingMaterial,
    String? ageBand,
  }) async {
    final trimmedMaterial = missingMaterial?.trim();
    final body = <String, dynamic>{
      'activityId': activityId,
      'adjustment': adjustment,
      if (trimmedMaterial != null && trimmedMaterial.isNotEmpty)
        'missingMaterial': trimmedMaterial.length > 60
            ? trimmedMaterial.substring(0, 60)
            : trimmedMaterial,
      if (ageBand != null && ageBand.isNotEmpty) 'ageBand': ageBand,
    };

    final data = await apiClient.post(
      '/api/v1/ai/adapt',
      body: body,
    ) as Map<String, dynamic>;

    return AdaptActivityResponse.fromJson(data);
  }
}
