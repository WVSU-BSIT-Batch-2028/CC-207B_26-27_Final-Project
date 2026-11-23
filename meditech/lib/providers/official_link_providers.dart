import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/official_link.dart';
import '../services/official_link_service.dart';

final officialLinkServiceProvider = Provider<OfficialLinkService>(
  (ref) => OfficialLinkService(Supabase.instance.client),
);

final fdaVerificationPortalProvider = FutureProvider.autoDispose<OfficialPortalLink?>(
  (ref) => ref.read(officialLinkServiceProvider).fdaVerificationPortal(),
);