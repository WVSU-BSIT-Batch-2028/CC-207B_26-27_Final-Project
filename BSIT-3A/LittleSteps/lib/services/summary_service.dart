import '../models/summary.dart';
import 'api_client.dart';

/// Service for retrieving weekly progress summaries.
class SummaryService {
  /// Creates a [SummaryService].
  SummaryService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  /// Fetches a child's weekly summary; [week] is an ISO week such as
  /// `2026-W47` and defaults to the current week.
  Future<WeeklySummary> getWeeklySummary(String childId, {String? week}) async {
    final data = await apiClient.get(
      '/api/v1/children/$childId/summary/weekly',
      queryParams: {'week': ?week},
    ) as Map<String, dynamic>;
    return WeeklySummary.fromJson(data);
  }
}
