import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pharmacy.dart';
import '../services/pharmacy_service.dart';
import '../utils/public_media_urls.dart';
import 'medicine_providers.dart';

// Provides PharmacyService (overridable in widget tests)
final pharmacyServiceProvider = Provider<PharmacyService>((ref) {
  return PharmacyService();
});

// Latest storefront photo path for any branch. Re-checks every 10 seconds
// while a screen shows it, so a new owner upload appears without a refresh.
final branchStorefrontPathProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, branchId) async {
  final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final detail = await ref
      .watch(pharmacyServiceProvider)
      .getPharmacyDetails(branchId: branchId);
  return detail?.storefrontPath;
});

// Viewable link for a storefront path. Keyed by path so the image only
// reloads when the owner actually uploads a different photo.
final storefrontUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, path) async {
  return pharmacyStorefrontSignedUrl(Supabase.instance.client, path);
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

// Loads approved branch info for Pharmacy Details, with live polling so storefront photo updates appear automatically
final pharmacyDetailProvider =
    FutureProvider.autoDispose.family<PharmacyDetail?, String>((ref, branchId) async {
  final service = ref.watch(pharmacyServiceProvider);
  final filter = ref.read(medicineSearchFilterProvider);

  final timer = Timer(const Duration(seconds: 6), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

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