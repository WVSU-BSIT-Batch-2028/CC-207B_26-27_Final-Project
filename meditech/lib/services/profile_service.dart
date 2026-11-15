import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_profile.dart';

// Reads the signed-in customer's own profile
abstract class ProfileService {
  Future<CustomerProfile?> loadMine();
}

class SupabaseProfileService implements ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<CustomerProfile?> loadMine() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;

    final row = await _client
        .from('customer_profiles')
        .select('first_name, middle_name, last_name, mobile, email, birthdate, consent_version')
        .eq('account_id', id)
        .maybeSingle();
    if (row == null) return null;
    return CustomerProfile.fromJson(row);
  }
}