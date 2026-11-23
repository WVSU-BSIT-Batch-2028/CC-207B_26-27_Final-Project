import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_profile.dart';
import '../models/customer_profile_overview.dart';
import '../services/profile_service.dart';
import 'session_providers.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return SupabaseProfileService();
});

// The profile for whoever is signed in
final customerProfileProvider = FutureProvider<CustomerProfile?>((ref) {
  if (ref.watch(sessionProvider) == null) {
    return Future.value(null);
  }
  return ref.watch(profileServiceProvider).loadMine();
});

/// Profile tab data: personal info, address count, notification prefs, avatar.
final customerProfileOverviewProvider =
    FutureProvider<CustomerProfileOverview?>((ref) {
  if (ref.watch(sessionProvider) == null) {
    return Future.value(null);
  }
  return ref.watch(profileServiceProvider).loadOverview();
});