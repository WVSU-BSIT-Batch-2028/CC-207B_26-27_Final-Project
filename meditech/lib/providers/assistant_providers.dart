import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/assistant_service.dart';

final assistantServiceProvider = Provider<AssistantService>((ref) {
  return SupabaseAssistantService();
});