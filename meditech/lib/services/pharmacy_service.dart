import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pharmacy.dart';

// Talks to Supabase for approved pharmacy branch details, hours, and inventory
class PharmacyService {
  PharmacyService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Loads approved branch header details (returns null if not active/found)
  Future<PharmacyDetail?> getPharmacyDetails({
    required String branchId,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'get_pharmacy_details',
      params: {
        'p_branch_id': branchId,
        'p_lat': latitude,
        'p_lng': longitude,
      },
    );

    final rows = response as List<dynamic>;
    if (rows.isEmpty) return null;
    return PharmacyDetail.fromJson(rows.first as Map<String, dynamic>);
  }

  // Loads weekly opening hours for an approved branch
  Future<List<PharmacyHours>> getPharmacyHours({
    required String branchId,
  }) async {
    final response = await _client.rpc(
      'get_pharmacy_hours',
      params: {'p_branch_id': branchId},
    );

    final rows = response as List<dynamic>;
    return rows
        .map((row) => PharmacyHours.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Loads active medicines offered by an approved branch
  Future<List<PharmacyInventoryItem>> getPharmacyInventory({
    required String branchId,
    String? query,
  }) async {
    final response = await _client.rpc(
      'get_pharmacy_inventory',
      params: {
        'p_branch_id': branchId,
        'p_query': query,
      },
    );

    final rows = response as List<dynamic>;
    return rows
        .map(
          (row) => PharmacyInventoryItem.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }
}