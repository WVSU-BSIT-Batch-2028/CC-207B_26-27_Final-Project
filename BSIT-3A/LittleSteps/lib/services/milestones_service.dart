import '../models/milestone.dart';
import 'api_client.dart';

/// Service for a child's milestone observations
/// (`/children/:childId/milestones`).
class MilestonesService {
  /// Creates a [MilestonesService].
  MilestonesService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  String _base(String childId) => '/api/v1/children/$childId/milestones';

  /// Lists saved observations, optionally filtered by [status] or
  /// [milestoneId].
  Future<List<MilestoneObservation>> getObservations(
    String childId, {
    String? status,
    String? milestoneId,
  }) async {
    final data = await apiClient.get(
      _base(childId),
      queryParams: {'status': ?status, 'milestoneId': ?milestoneId},
    ) as List<dynamic>;
    return data
        .map((e) => MilestoneObservation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves a first observation for the prompt [milestoneId].
  Future<MilestoneObservation> createObservation({
    required String childId,
    required String milestoneId,
    required String status,
    String? observedDate,
    String? notes,
  }) async {
    final data = await apiClient.post(
      _base(childId),
      body: {
        'milestoneId': milestoneId,
        'status': status,
        'observedDate': ?observedDate,
        'notes': ?notes,
      },
    ) as Map<String, dynamic>;
    return MilestoneObservation.fromJson(data);
  }

  /// Changes an existing observation, found by its [observationId].
  Future<MilestoneObservation> updateObservation({
    required String childId,
    required String observationId,
    String? status,
    String? observedDate,
    String? notes,
  }) async {
    final data = await apiClient.patch(
      '${_base(childId)}/$observationId',
      body: {'status': ?status, 'observedDate': ?observedDate, 'notes': ?notes},
    ) as Map<String, dynamic>;
    return MilestoneObservation.fromJson(data);
  }
}
