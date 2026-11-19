import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_request.dart';
import '../services/medicine_request_service.dart';

// Gives screens the medicine request service
final medicineRequestServiceProvider = Provider<MedicineRequestService>(
  (ref) => MedicineRequestService(Supabase.instance.client),
);

// The chosen status tab (null means All); starts on Open
class RequestStatusController extends Notifier<String?> {
  @override
  String? build() => 'open';

  void set(String? status) => state = status;
}

final requestStatusProvider =
    NotifierProvider<RequestStatusController, String?>(RequestStatusController.new);

// The admin's request list; reloads when the tab changes
final requestListProvider = FutureProvider.autoDispose<List<MedicineRequest>>((ref) {
  final status = ref.watch(requestStatusProvider);
  return ref.read(medicineRequestServiceProvider).list(status: status);
});