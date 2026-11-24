import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pharmacy.dart';
import '../services/pharmacy_service.dart';
import 'medicine_providers.dart';

// Provides PharmacyService (overridable in widget tests)
final pharmacyServiceProvider = Provider<PharmacyService>((ref) {
  return PharmacyService();
});

// Approved branches shown on guest/home browse
final publicBranchesProvider =
    FutureProvider.autoDispose<List<PharmacyDetail>>((ref) async {
  return ref.watch(pharmacyServiceProvider).listPublicBranches();
});

// Opening hours keyed by branch, used by the home "Open now" filter
final publicBranchHoursProvider =
    FutureProvider.autoDispose<Map<String, List<PharmacyHours>>>((ref) async {
  return ref.watch(pharmacyServiceProvider).listPublicHours();
});

// Loads approved branch info for Pharmacy Details
final pharmacyDetailProvider =
    FutureProvider.family<PharmacyDetail?, String>((ref, branchId) async {
  final service = ref.watch(pharmacyServiceProvider);
  // Read once per fetch so cart/location filter updates do not reload the store.
  final filter = ref.read(medicineSearchFilterProvider);

  return service.getPharmacyDetails(
    branchId: branchId,
    latitude: filter.latitude,
    longitude: filter.longitude,
  );
});

// Loads weekly opening hours for a branch
final pharmacyHoursProvider =
    FutureProvider.family<List<PharmacyHours>, String>((ref, branchId) async {
  final service = ref.watch(pharmacyServiceProvider);
  return service.getPharmacyHours(branchId: branchId);
});

// Holds the in-branch medicine search query on Pharmacy Details
class PharmacyInventoryQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }
}

final pharmacyInventoryQueryProvider =
    NotifierProvider<PharmacyInventoryQueryNotifier, String>(
  PharmacyInventoryQueryNotifier.new,
);

// Loads active medicines offered by a branch, filtered by the in-branch search bar
final pharmacyInventoryProvider =
    FutureProvider.family<List<PharmacyInventoryItem>, String>(
        (ref, branchId) async {
  final service = ref.watch(pharmacyServiceProvider);
  final query = ref.watch(pharmacyInventoryQueryProvider).trim();

  return service.getPharmacyInventory(
    branchId: branchId,
    query: query.isEmpty ? null : query,
  );
});