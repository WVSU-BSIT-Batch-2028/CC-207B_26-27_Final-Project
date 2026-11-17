import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/application_details.dart';
import '../models/pharmacy_summary.dart';
import '../services/admin_pharmacy_service.dart';
import '../models/verification_check.dart';

// Gives screens the admin pharmacy service
final adminPharmacyServiceProvider = Provider<AdminPharmacyService>(
  (ref) => AdminPharmacyService(Supabase.instance.client),
);

// The chosen status tab and search text
class PharmacyFilter {
  const PharmacyFilter({this.status, this.search = ''});

  final String? status; // null means All
  final String search;
}

class PharmacyFilterController extends Notifier<PharmacyFilter> {
  @override
  PharmacyFilter build() => const PharmacyFilter();

  // Switch status tab
  void setStatus(String? status) => state = PharmacyFilter(status: status, search: state.search);

  // Search for a pharmacy, owner, LTO, or PHM number
  void setSearch(String search) => state = PharmacyFilter(status: state.status, search: search.trim());
}

final pharmacyFilterProvider =
    NotifierProvider<PharmacyFilterController, PharmacyFilter>(PharmacyFilterController.new);

// The table rows; reloads whenever the filter changes
final pharmacyListProvider = FutureProvider.autoDispose<List<PharmacySummary>>((ref) {
  final filter = ref.watch(pharmacyFilterProvider);
  return ref.read(adminPharmacyServiceProvider).list(
        status: filter.status,
        search: filter.search.isEmpty ? null : filter.search,
      );
});

// The application currently open in the drawer
class SelectedPharmacyController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedPharmacyProvider =
    NotifierProvider<SelectedPharmacyController, String?>(SelectedPharmacyController.new);

// One application's details, for the drawer
final applicationDetailsProvider =
    FutureProvider.autoDispose.family<ApplicationDetails?, String>(
  (ref, id) => ref.read(adminPharmacyServiceProvider).details(id),
);

// A pharmacy's FDA check history
final branchChecksProvider = FutureProvider.autoDispose.family<List<VerificationCheck>, String>(
  (ref, id) => ref.read(adminPharmacyServiceProvider).checks(id),
);

// Whether the pharmacy can be approved right now
final branchHasMatchProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.read(adminPharmacyServiceProvider).hasCurrentMatch(id),
);