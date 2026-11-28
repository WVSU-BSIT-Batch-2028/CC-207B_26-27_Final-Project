import '../models/child.dart';
import 'api_client.dart';

/// Service for managing child profiles.
class ChildrenService {
  /// Creates a [ChildrenService].
  ChildrenService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  /// Fetches all registered child profiles.
  Future<List<Child>> getChildren() async {
    final data =
        await apiClient.get('/api/v1/children') as List<dynamic>? ?? [];
    return data.map((e) => Child.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetches a child profile by its unique identifier.
  Future<Child> getChildById(String id) async {
    final data =
        await apiClient.get('/api/v1/children/$id') as Map<String, dynamic>;
    return Child.fromJson(data);
  }

  /// Creates a new child profile.
  Future<Child> createChild({
    required String nickname,
    String? ageBand,
    String? birthMonthYear,
  }) async {
    final body = <String, dynamic>{'nickname': nickname};
    if (ageBand != null) body['ageBand'] = ageBand;
    if (birthMonthYear != null) body['birthMonthYear'] = birthMonthYear;

    final data = await apiClient.post(
      '/api/v1/children',
      body: body,
    ) as Map<String, dynamic>;
    return Child.fromJson(data);
  }

  /// Updates an existing child profile.
  Future<Child> updateChild({
    required String id,
    String? nickname,
    String? ageBand,
    String? birthMonthYear,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (ageBand != null) body['ageBand'] = ageBand;
    if (birthMonthYear != null) body['birthMonthYear'] = birthMonthYear;

    final data = await apiClient.patch(
      '/api/v1/children/$id',
      body: body,
    ) as Map<String, dynamic>;
    return Child.fromJson(data);
  }

  /// Deletes a child profile by its unique identifier.
  Future<void> deleteChild(String id) async {
    await apiClient.delete('/api/v1/children/$id');
  }
}
