import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/branch_reservation.dart';
import '../services/branch_reservation_service.dart';
import 'session_providers.dart';

// Provides the reservation service (defaults to FakeBranchReservationService unless Supabase is ready)
final branchReservationServiceProvider =
    Provider<BranchReservationService>((ref) {
  try {
    final client = Supabase.instance.client;
    return SupabaseBranchReservationService(client);
  } catch (_) {
    return FakeBranchReservationService();
  }
});

// Holds all reservations for the current active pharmacy branch
final branchReservationsProvider =
    AsyncNotifierProvider<BranchReservationsNotifier, List<BranchReservation>>(
  BranchReservationsNotifier.new,
);

class BranchReservationsNotifier
    extends AsyncNotifier<List<BranchReservation>> {
  @override
  Future<List<BranchReservation>> build() async {
    final session = ref.watch(sessionProvider);
    final branchId = session?.branchId ?? 'demo-branch';
    final service = ref.watch(branchReservationServiceProvider);
    return service.getReservations(branchId);
  }

  // Reload the branch reservations list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = ref.read(sessionProvider);
      final branchId = session?.branchId ?? 'demo-branch';
      final service = ref.read(branchReservationServiceProvider);
      return service.getReservations(branchId);
    });
  }

  // Pharmacist confirms a pending reservation
  Future<void> confirm(String reservationId) async {
    final service = ref.read(branchReservationServiceProvider);
    await service.confirmReservation(reservationId);
    await refresh();
  }

  // Pharmacist rejects a pending reservation with a reason
  Future<void> reject(String reservationId, String reason) async {
    final service = ref.read(branchReservationServiceProvider);
    await service.rejectReservation(reservationId, reason);
    await refresh();
  }

  // Staff marks a confirmed reservation as ready for pickup
  Future<void> markReady(String reservationId) async {
    final service = ref.read(branchReservationServiceProvider);
    await service.markReady(reservationId);
    await refresh();
  }

  // Verify pickup code (does not complete)
  Future<bool> checkCode(String reservationId, String code) async {
    final service = ref.read(branchReservationServiceProvider);
    return service.checkPickupCode(reservationId, code);
  }

  // Complete and release reservation
  Future<void> complete(String reservationId, String code) async {
    final service = ref.read(branchReservationServiceProvider);
    await service.completeReservation(reservationId, code);
    await refresh();
  }

  // Owner or pharmacist cancels a confirmed/ready reservation with reason
  Future<void> cancel(String reservationId, String reason) async {
    final service = ref.read(branchReservationServiceProvider);
    await service.cancelReservation(reservationId, reason);
    await refresh();
  }
}

// Holds the currently selected reservation ID for the tablet drawer
class SelectedReservationIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedReservationIdProvider =
    NotifierProvider<SelectedReservationIdNotifier, String?>(
  SelectedReservationIdNotifier.new,
);

// Fetches deep details for the selected reservation
final selectedReservationDetailProvider =
    FutureProvider<BranchReservation?>((ref) async {
  final id = ref.watch(selectedReservationIdProvider);
  if (id == null) return null;
  final service = ref.watch(branchReservationServiceProvider);
  return service.getReservationDetails(id);
});
