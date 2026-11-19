import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_request.dart';

// Sending and reviewing medicine requests
class MedicineRequestService {
  MedicineRequestService(this._client);

  final SupabaseClient _client;

  // A pharmacy sends a request; returns its number, like REQ-000001
  Future<String> submit(Map<String, dynamic> details) async {
    return await _client.rpc('submit_medicine_request', params: {'p': details}) as String;
  }

  // Admin list, optionally only one status
  Future<List<MedicineRequest>> list({String? status}) async {
    final rows = await _client.rpc('admin_list_medicine_requests', params: {'p_status': status}) as List;
    return rows.map((r) => MedicineRequest.fromJson(r as Map<String, dynamic>)).toList();
  }

  // Link the request to the medicine that was added to the catalogue
  Future<void> markAdded(String requestId, String medicineId) async {
    await _client.rpc('mark_request_added', params: {
      'p_request_id': requestId,
      'p_medicine_id': medicineId,
    });
  }

  // Dismiss with a reason the pharmacy will see
  Future<void> dismiss(String requestId, String reason) async {
    await _client.rpc('dismiss_medicine_request', params: {
      'p_request_id': requestId,
      'p_reason': reason,
    });
  }

  // Turn server errors into friendly messages
  static String friendlyError(Object error) {
    final text = error is PostgrestException ? error.message : error.toString();
    if (text.contains('DUPLICATE_REQUEST')) {
      return 'You already have an open request for this medicine.';
    }
    if (text.contains('NOT_ALLOWED')) return 'Only approved pharmacies can request medicines.';
    if (text.contains('NOT_OPEN')) return 'This request was already handled.';
    if (text.contains('REASON_LENGTH')) return 'The reason must be 5 to 200 characters.';
    if (text.contains('generic_name')) return 'Enter the generic name (2 to 100 characters).';
    return 'Something went wrong. Please try again.';
  }
}