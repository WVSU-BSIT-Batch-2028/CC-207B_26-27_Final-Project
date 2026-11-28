import '../models/plan.dart';
import 'api_client.dart';

/// Service for a child's planned activities (`/children/:childId/plans`).
class PlanService {
  /// Creates a [PlanService].
  PlanService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  String _base(String childId) => '/api/v1/children/$childId/plans';

  /// Lists plans, optionally filtered by [date] (`YYYY-MM-DD`) and [status].
  Future<List<PlanItem>> getPlans(
    String childId, {
    String? date,
    String? status,
  }) async {
    final data = await apiClient.get(
      _base(childId),
      queryParams: {'date': ?date, 'status': ?status},
    ) as List<dynamic>;
    return data
        .map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adds a catalog or custom activity to the child's plan on [scheduledDate].
  Future<PlanItem> addActivityToPlan({
    required String childId,
    required String activityId,
    required String scheduledDate,
    int? durationMinutes,
    CustomPlanActivity? customActivity,
  }) async {
    final data = await apiClient.post(
      _base(childId),
      body: {
        'activityId': activityId,
        'scheduledDate': scheduledDate,
        'durationMinutes': ?durationMinutes,
        if (customActivity != null) 'customActivity': customActivity.toJson(),
      },
    ) as Map<String, dynamic>;
    return PlanItem.fromJson(data);
  }

  /// Sets a plan's [status] (`planned`, `completed` or `skipped`).
  Future<PlanItem> updatePlanStatus({
    required String childId,
    required String planId,
    required String status,
  }) async {
    final data = await apiClient.patch(
      '${_base(childId)}/$planId',
      body: {'status': status},
    ) as Map<String, dynamic>;
    return PlanItem.fromJson(data);
  }

  /// Removes a plan.
  Future<void> deletePlan({
    required String childId,
    required String planId,
  }) async {
    await apiClient.delete('${_base(childId)}/$planId');
  }
}
