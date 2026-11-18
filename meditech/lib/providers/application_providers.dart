import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/application_status.dart';
import '../services/application_service.dart';

// Gives screens the application service
final applicationServiceProvider = Provider<ApplicationService>(
  (ref) => ApplicationService(Supabase.instance.client),
);

// The signed-in owner's application; reloads each time the screen opens
final myApplicationProvider = FutureProvider.autoDispose<ApplicationStatus?>(
  (ref) => ref.read(applicationServiceProvider).myApplication(),
);