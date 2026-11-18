import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_profile.dart';
import '../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return SupabaseProfileService();
});

// The profile for whoever is signed in
final customerProfileProvider = FutureProvider<CustomerProfile?>((ref) {
  return ref.watch(profileServiceProvider).loadMine();
});