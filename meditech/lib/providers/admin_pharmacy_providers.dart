import 'package:flutter/material.dart' show DateUtils;
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

// How far ahead an LTO counts as "expiring soon" (matches the admin overview)
const ltoExpiringWindowDays = 60;

// An active pharmacy whose LTO runs out within the window (or already has)
bool isLtoExpiringSoon(PharmacySummary p, DateTime today) =>
    p.status == 'active' &&
    !p.ltoExpiry.isAfter(DateUtils.dateOnly(today).add(const Duration(days: ltoExpiringWindowDays)));

// Every pharmacy; the screen searches, filters, sorts, and pages on the device
final pharmacyListProvider = FutureProvider.autoDispose<List<PharmacySummary>>(
  (ref) => ref.read(adminPharmacyServiceProvider).list(),
);

// The application currently open in the drawer
class SelectedPharmacyController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedPharmacyProvider = NotifierProvider<SelectedPharmacyController, String?>(SelectedPharmacyController.new);

// One application's details, for the drawer
final applicationDetailsProvider = FutureProvider.autoDispose.family<ApplicationDetails?, String>(
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
