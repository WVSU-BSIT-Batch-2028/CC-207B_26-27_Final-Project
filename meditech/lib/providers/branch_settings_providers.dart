import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/branch_settings.dart';
import '../services/branch_settings_service.dart';

// Provider for the BranchSettingsService
final branchSettingsServiceProvider = Provider<BranchSettingsService>((ref) {
  return BranchSettingsService();
});

// Asynchronously loads current branch settings
final branchSettingsProvider =
    FutureProvider.autoDispose<BranchSettings>((ref) async {
  final service = ref.watch(branchSettingsServiceProvider);
  return service.loadSettings();
});
