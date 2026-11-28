import 'api_client.dart';

/// Caregiver data export and account deletion operations.
class AccountService {
  /// Creates an [AccountService].
  AccountService({required this.apiClient});

  /// Client used for authenticated account requests.
  final ApiClient apiClient;

  /// Exports the signed-in caregiver's account and child records as JSON.
  Future<Map<String, dynamic>> exportData() async {
    final data = await apiClient.get('/api/v1/me/export');
    if (data is! Map<String, dynamic>) {
      throw const FormatException('The data export response was invalid.');
    }
    return data;
  }

  /// Permanently deletes the signed-in caregiver account and associated data.
  Future<void> deleteAccount() async {
    await apiClient.delete('/api/v1/me');
  }
}
