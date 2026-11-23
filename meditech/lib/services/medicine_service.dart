import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine.dart';
import 'medicine_image_fallback.dart';

// Talks to Supabase to search medicines and load pharmacy offers
class MedicineService {
  MedicineService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Searches active medicines with optional filters and sorting
  Future<List<MedicineSearchResult>> searchMedicines({
    String? query,
    String? strength,
    String? dosageForm,
    String? location,
    String sort = 'relevance',
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'search_medicines',
      params: {
        'p_query': query,
        'p_strength': strength,
        'p_dosage_form': dosageForm,
        'p_location': location,
        'p_sort': sort,
        'p_lat': latitude,
        'p_lng': longitude,
      },
    );

    final rows = response as List<dynamic>;
    final results = rows
        .map((row) => MedicineSearchResult.fromJson(row as Map<String, dynamic>))
        .toList();

    final missing =
        results.where((m) => m.imagePath == null || m.imagePath!.isEmpty).map((m) => m.medicineId);
    final paths = await medicineImagePathsById(_client, missing);
    if (paths.isEmpty) return results;

    return [
      for (final m in results)
        if (paths[m.medicineId] != null && (m.imagePath == null || m.imagePath!.isEmpty))
          MedicineSearchResult(
            medicineId: m.medicineId,
            displayId: m.displayId,
            brandName: m.brandName,
            genericName: m.genericName,
            strength: m.strength,
            dosageForm: m.dosageForm,
            unitSold: m.unitSold,
            isRx: m.isRx,
            lowestPrice: m.lowestPrice,
            pharmacyCount: m.pharmacyCount,
            nearestKm: m.nearestKm,
            imagePath: paths[m.medicineId],
          )
        else
          m,
    ];
  }

  // Loads approved pharmacy offers for a single medicine
  Future<List<MedicineOffer>> getMedicineOffers({
    required String medicineId,
    String sort = 'price',
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'get_medicine_offers',
      params: {
        'p_medicine_id': medicineId,
        'p_sort': sort,
        'p_lat': latitude,
        'p_lng': longitude,
      },
    );

    final rows = response as List<dynamic>;
    return rows
        .map((row) => MedicineOffer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Loads active dosage form names for the search filter chips
  Future<List<String>> getDosageForms() async {
    final response = await _client
        .from('dosage_forms')
        .select('name')
        .order('id', ascending: true);

    final rows = response as List<dynamic>;
    return rows
        .map((row) => (row as Map<String, dynamic>)['name'] as String)
        .toList();
  }
}