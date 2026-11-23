import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pharmacy.dart';
import 'medicine_image_fallback.dart';

// Talks to Supabase for approved pharmacy branch details, hours, and inventory
class PharmacyService {
  PharmacyService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Loads approved branches for guest/home "Browse All Stores"
  Future<List<PharmacyDetail>> listPublicBranches() async {
    final response = await _client
        .from('public_branches')
        .select(
          'id, display_id, pharmacy_name, branch_name, address, contact_number, latitude, longitude',
        )
        .order('pharmacy_name', ascending: true);

    final rows = response as List<dynamic>;
    return rows.map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      return PharmacyDetail.fromJson({
        'branch_id': json['id'],
        'display_id': json['display_id'],
        'pharmacy_name': json['pharmacy_name'],
        'branch_name': json['branch_name'],
        'address': json['address'],
        'contact_number': json['contact_number'] ?? '',
        'latitude': json['latitude'],
        'longitude': json['longitude'],
        'distance_km': null,
      });
    }).toList();
  }

  // Opening hours for every approved branch, grouped by branch id
  Future<Map<String, List<PharmacyHours>>> listPublicHours() async {
    final response = await _client
        .from('public_branch_hours')
        .select('branch_id, weekday, opens_at, closes_at, is_closed');

    final grouped = <String, List<PharmacyHours>>{};
    for (final row in response as List<dynamic>) {
      final json = Map<String, dynamic>.from(row as Map);
      final branchId = '${json['branch_id']}';
      grouped.putIfAbsent(branchId, () => []).add(PharmacyHours.fromJson(json));
    }
    return grouped;
  }

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
    final items = rows
        .map(
          (row) => PharmacyInventoryItem.fromJson(row as Map<String, dynamic>),
        )
        .toList();

    final missing =
        items.where((i) => i.imagePath == null || i.imagePath!.isEmpty).map((i) => i.medicineId);
    final paths = await medicineImagePathsById(_client, missing);
    if (paths.isEmpty) return items;

    return [
      for (final i in items)
        if (paths[i.medicineId] != null && (i.imagePath == null || i.imagePath!.isEmpty))
          PharmacyInventoryItem(
            inventoryId: i.inventoryId,
            medicineId: i.medicineId,
            medicineDisplayId: i.medicineDisplayId,
            brandName: i.brandName,
            genericName: i.genericName,
            strength: i.strength,
            dosageForm: i.dosageForm,
            unitSold: i.unitSold,
            packDescription: i.packDescription,
            isRx: i.isRx,
            pricePerUnit: i.pricePerUnit,
            availability: i.availability,
            stockConfirmedAt: i.stockConfirmedAt,
            imagePath: paths[i.medicineId],
          )
        else
          i,
    ];
  }
}