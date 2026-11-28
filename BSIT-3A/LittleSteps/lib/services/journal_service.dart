import '../models/journal_entry.dart';
import 'api_client.dart';

/// Service for managing private caregiver journal entries.
class JournalService {
  /// Creates a [JournalService].
  JournalService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  /// Fetches journal entries recorded for a specific child.
  Future<List<JournalEntry>> getJournalEntries(String childId) async {
    final data =
        await apiClient.get('/api/v1/children/$childId/journal')
            as List<dynamic>? ??
        [];
    return data
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new private journal entry.
  Future<JournalEntry> createJournalEntry({
    required String childId,
    required String entryDate,
    required String content,
  }) async {
    final body = {'entryDate': entryDate, 'content': content};
    final data = await apiClient.post(
      '/api/v1/children/$childId/journal',
      body: body,
    ) as Map<String, dynamic>;
    return JournalEntry.fromJson(data);
  }

  /// Updates the content of an existing journal entry, and its date when
  /// [entryDate] (`YYYY-MM-DD`) is given.
  Future<JournalEntry> updateJournalEntry({
    required String childId,
    required String entryId,
    required String content,
    String? entryDate,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (entryDate != null) body['entryDate'] = entryDate;
    final data = await apiClient.patch(
      '/api/v1/children/$childId/journal/$entryId',
      body: body,
    ) as Map<String, dynamic>;
    return JournalEntry.fromJson(data);
  }

  /// Deletes a journal entry.
  Future<void> deleteJournalEntry({
    required String childId,
    required String entryId,
  }) async {
    await apiClient.delete('/api/v1/children/$childId/journal/$entryId');
  }
}
