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
  RealtimeChannel? _channel;

  @override
  Future<List<BranchReservation>> build() async {
    ref.onDispose(_unsubscribe);
    restoreSessionIfNeeded(
      currentSession: ref.read(sessionProvider),
      setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
    );
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.branchId != next?.branchId || (previous == null) != (next == null)) {
        ref.invalidateSelf();
      }
    });

    if (ref.read(sessionProvider) == null && !_hasSupabaseSession()) {
      return const [];
    }

    final branchId = await _resolveBranchId();
    if (branchId == null) {
      return const [];
    }
    _subscribeToBranchReservations(branchId);
    final service = ref.read(branchReservationServiceProvider);
    return service.getReservations(branchId);
  }

  void _subscribeToBranchReservations(String branchId) {
    _unsubscribe();
    try {
      final client = Supabase.instance.client;
      _channel = client
          .channel('branch-reservations-$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    } catch (_) {
      // Realtime optional when not configured (tests / offline).
    }
  }

  void _unsubscribe() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {}
    }
  }

  bool _hasSupabaseSession() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveBranchId() async {
    if (ref.read(sessionProvider) == null && !_hasSupabaseSession()) {
      return null;
    }
    try {
      final client = Supabase.instance.client;
      final id = await client.rpc('my_branch_id');
      if (id != null && id.toString().isNotEmpty) {
        return id as String;
      }
    } catch (_) {
      // Fall back to JWT claim below.
    }
    return ref.read(sessionProvider)?.branchId;
  }

  // Reload the branch reservations list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final branchId = await _resolveBranchId();
      if (branchId == null) return const <BranchReservation>[];
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
