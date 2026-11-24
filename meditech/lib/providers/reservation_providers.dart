import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reservation.dart';
import '../services/reservation_service.dart';
import 'cart_providers.dart';
import 'session_providers.dart';

// Provides the ReservationService instance (overridable in widget tests)
final reservationServiceProvider = Provider<ReservationService>((ref) {
  return ReservationService();
});

// Holds the signed-in customer's reservations list and refreshes on live updates
class MyReservationsNotifier extends AsyncNotifier<List<CustomerReservation>> {
  RealtimeChannel? _channel;

  @override
  Future<List<CustomerReservation>> build() async {
    ref.onDispose(_unsubscribe);
    restoreSessionIfNeeded(
      currentSession: ref.read(sessionProvider),
      setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
    );
    ref.listen(sessionProvider, (previous, next) {
      if (next == null) _unsubscribe();
    });

    final userId = _tryCurrentUserId();
    if (userId == null) {
      return const [];
    }
    if (ref.watch(sessionProvider) == null &&
        signedInAccountFromStoredSession() == null) {
      return const [];
    }
    final service = ref.watch(reservationServiceProvider);
    _subscribeToUpdates(userId);

    return service.getMyReservations();
  }

  String? _tryCurrentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  void _subscribeToUpdates(String userId) {
    _unsubscribe();
    try {
      final client = Supabase.instance.client;
      _channel = client
          .channel('customer-reservations-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: userId,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    } catch (_) {
      // Ignore Realtime subscription when Supabase isn't initialized in tests
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

  // Reloads the customer's reservations from Supabase
  Future<void> refresh() async {
    if (!ref.mounted) return;
    restoreSessionIfNeeded(
      currentSession: ref.read(sessionProvider),
      setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
    );
    if (_tryCurrentUserId() == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(reservationServiceProvider).getMyReservations(),
    );
  }

  // Cancels a pending reservation placed by the signed-in customer
  Future<void> cancelMyReservation(String reservationId) async {
    final service = ref.read(reservationServiceProvider);
    await service.cancelMyReservation(reservationId);
    await refresh();
  }

  // Submits the current cart as a reservation, refreshes cart & reservations
  Future<SubmittedReservationResult> submitReservation({
    required String idempotencyKey,
    required bool acknowledged,
  }) async {
    final service = ref.read(reservationServiceProvider);
    final result = await service.submitReservation(
      idempotencyKey: idempotencyKey,
      acknowledged: acknowledged,
    );
    await ref.read(cartProvider.notifier).refresh();
    try {
      final fresh = await service.getReservationById(result.reservationId);
      if (fresh != null) {
        final existing = state.value ?? const <CustomerReservation>[];
        final merged = [
          fresh,
          ...existing.where((r) => r.id != fresh.id),
        ];
        state = AsyncData(merged);
      }
    } catch (_) {
      // List refresh still runs below.
    }
    await refresh();
    return result;
  }
}

final myReservationsProvider =
    AsyncNotifierProvider<MyReservationsNotifier, List<CustomerReservation>>(
      MyReservationsNotifier.new,
    );

// Convenience provider for the latest active reservation card on Home
final latestActiveReservationProvider = Provider<CustomerReservation?>((ref) {
  final list = ref.watch(myReservationsProvider).value ?? const [];
  for (final reservation in list) {
    if (reservation.status.isActive) {
      return reservation;
    }
  }
  return null;
});

// Fetches a single reservation by ID for Reservation Details (auto-refreshes when list updates)
final reservationDetailProvider =
    FutureProvider.family<CustomerReservation?, String>((ref, reservationId) {
      ref.watch(myReservationsProvider);
      return ref
          .read(reservationServiceProvider)
          .getReservationById(reservationId);
    });