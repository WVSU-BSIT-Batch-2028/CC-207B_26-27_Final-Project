import '../models/activity.dart';
import '../models/book.dart';
import '../models/milestone.dart';
import '../models/rhyme.dart';
import '../models/weather.dart';
import 'api_client.dart';

/// Service for accessing activities, milestones, rhymes, books, and weather.
class CatalogService {
  /// Creates a [CatalogService].
  CatalogService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  /// Fetches learning activities filtered by age band, domain, or setting.
  Future<List<Activity>> getActivities({
    String? ageBand,
    String? domain,
    String? language,
    String? setting,
    int limit = 50,
  }) async {
    final data = await apiClient.get(
      '/api/v1/catalog/activities',
      queryParams: {
        'ageBand': ?ageBand,
        'domain': ?domain,
        'language': ?language,
        'setting': ?setting,
        'limit': limit.toString(),
      },
    ) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches an activity by its unique identifier.
  Future<Activity> getActivityById(String id) async {
    final data = await apiClient.get(
      '/api/v1/catalog/activities/$id',
    ) as Map<String, dynamic>;
    return Activity.fromJson(data);
  }

  /// Fetches reference developmental milestone prompts from the catalog.
  Future<List<MilestonePrompt>> getMilestones({
    String? ageBand,
    String? domain,
    int limit = 50,
  }) async {
    final data = await apiClient.get(
      '/api/v1/catalog/milestones',
      queryParams: {
        'ageBand': ?ageBand,
        'domain': ?domain,
        'limit': limit.toString(),
      },
    ) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => MilestonePrompt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches Philippine traditional rhymes and action songs from the catalog.
  Future<List<PhilippineRhyme>> getRhymes({
    String? domain,
    String? language,
    int limit = 50,
  }) async {
    final data = await apiClient.get(
      '/api/v1/catalog/rhymes',
      queryParams: {
        'domain': ?domain,
        'language': ?language,
        'limit': limit.toString(),
      },
    ) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => PhilippineRhyme.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches recommended picture books for young children.
  Future<List<Book>> getBooks({
    String subject = 'picture_books',
    int limit = 12,
  }) async {
    final data = await apiClient.get(
      '/api/v1/catalog/books',
      queryParams: {'subject': subject, 'limit': limit.toString()},
    ) as Map<String, dynamic>;
    final books = data['books'] as List<dynamic>? ?? [];
    return books.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetches local weather guidance for activity planning.
  ///
  /// The hint is optional, so any failure returns an "unavailable" hint
  /// instead of an error.
  Future<WeatherHint> getWeather({
    double latitude = 10.72,
    double longitude = 122.56,
  }) async {
    try {
      final data = await apiClient.get(
        '/api/v1/catalog/weather',
        queryParams: {
          'latitude': latitude.toStringAsFixed(2),
          'longitude': longitude.toStringAsFixed(2),
        },
      ) as Map<String, dynamic>;
      return WeatherHint.fromJson(data);
    } catch (_) {
      return const WeatherHint(
        condition: 'unavailable',
        rainChance: 0,
        heatFlag: false,
        suggestedSetting: WeatherHint.settingEither,
        hint: null,
        attribution: 'Weather data by Open-Meteo.com',
      );
    }
  }
}
