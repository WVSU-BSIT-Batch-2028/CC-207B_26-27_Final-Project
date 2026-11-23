import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/official_link.dart';

class OfficialLinkService {
  OfficialLinkService(this._client);

  final SupabaseClient _client;

  static const _fdaKey = 'fda_verification_portal';

  Future<OfficialPortalLink?> fdaVerificationPortal() async {
    final row = await _client
        .from('official_links')
        .select('label, url')
        .eq('key', _fdaKey)
        .maybeSingle();
    if (row == null) return null;
    return OfficialPortalLink.fromJson(Map<String, dynamic>.from(row));
  }
}