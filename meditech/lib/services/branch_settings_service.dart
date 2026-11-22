import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_settings.dart';

// Service for loading and updating branch settings and profile (Ph-36)
class BranchSettingsService {
  BranchSettingsService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    final client = _providedClient;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  // Loads current branch settings including FDA LTO and owner license
  Future<BranchSettings> loadSettings() async {
    final response = await _client
        .from('branches')
        .select('''
          id,
          name,
          address,
          contact_number,
          email,
          opening_time,
          closing_time,
          days_open,
          latitude,
          longitude,
          fda_lto,
          fda_lto_expiry,
          owner_account_id,
          accounts!branches_owner_account_id_fkey (
            prc_license_number,
            prc_license_expiry
          )
        ''')
        .limit(1)
        .maybeSingle();

    if (response == null) {
      throw Exception('Branch settings not found.');
    }

    final ownerMap = response['accounts'] as Map<String, dynamic>?;
    final opening = response['opening_time']?.toString() ?? '8:00 AM';
    final closing = response['closing_time']?.toString() ?? '8:00 PM';
    final days = response['days_open']?.toString() ?? 'Mon-Sat';

    return BranchSettings(
      branchId: response['id']?.toString() ?? '',
      pharmacyName: response['name']?.toString() ?? '',
      branchName: response['name']?.toString() ?? '',
      address: response['address']?.toString() ?? '',
      contactNumber: response['contact_number']?.toString() ?? '',
      pharmacyEmail: response['email']?.toString() ?? '',
      operatingHours: '$days, $opening – $closing',
      latitude: (response['latitude'] as num?)?.toDouble(),
      longitude: (response['longitude'] as num?)?.toDouble(),
      fdaLto: response['fda_lto']?.toString() ?? '',
      fdaLtoExpiry: response['fda_lto_expiry'] != null
          ? DateTime.tryParse(response['fda_lto_expiry'].toString())
          : null,
      ownerPrcLicense: ownerMap?['prc_license_number']?.toString(),
      ownerPrcExpiry: ownerMap?['prc_license_expiry'] != null
          ? DateTime.tryParse(ownerMap!['prc_license_expiry'].toString())
          : null,
      isOwnerPharmacist: (ownerMap?['prc_license_number']?.toString().isNotEmpty ?? false),
    );
  }

  // Updates branch profile and operating details
  Future<void> updateSettings({
    required String branchId,
    required String address,
    required String contactNumber,
    required String operatingHours,
    double? latitude,
    double? longitude,
    String? ownerPrcLicense,
    DateTime? ownerPrcExpiry,
  }) async {
    await _client.from('branches').update({
      'address': address,
      'contact_number': contactNumber,
      ...?latitude != null ? {'latitude': latitude} : null,
      ...?longitude != null ? {'longitude': longitude} : null,
    }).eq('id', branchId);

    // If owner license updated, update the owner account row
    if (ownerPrcLicense != null && ownerPrcLicense.isNotEmpty) {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('accounts').update({
          'prc_license_number': ownerPrcLicense,
          if (ownerPrcExpiry != null)
            'prc_license_expiry': ownerPrcExpiry.toIso8601String(),
        }).eq('id', user.id);
      }
    }
  }
}
