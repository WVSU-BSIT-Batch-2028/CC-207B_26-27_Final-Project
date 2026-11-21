import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lto_renewal.dart';
import '../services/lto_renewal_service.dart';

// Gives screens the renewal service
final ltoRenewalServiceProvider = Provider<LtoRenewalService>(
  (ref) => LtoRenewalService(Supabase.instance.client),
);

// The signed-in owner's pharmacy
final ownBranchProvider = FutureProvider.autoDispose<OwnBranch?>(
  (ref) => ref.read(ltoRenewalServiceProvider).myBranch(),
);

// The newest renewal for a pharmacy (owner or admin)
final latestRenewalProvider = FutureProvider.autoDispose.family<LtoRenewal?, String>(
  (ref, branchId) => ref.read(ltoRenewalServiceProvider).latestFor(branchId),
);