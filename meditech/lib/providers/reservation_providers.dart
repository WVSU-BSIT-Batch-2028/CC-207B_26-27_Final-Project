import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reservation.dart';
import '../services/reservation_service.dart';
import 'cart_providers.dart';

// Provides the ReservationService instance (overridable in widget tests)
final reservationServiceProvider = Provider<ReservationService>((ref) {
  return ReservationService();
});

// Holds the signed-in customer's reservations list and refreshes on live updates
class MyReservationsNotifier extends AsyncNotifier<List<CustomerReservation>> {
  RealtimeChannel? _channel;

  @override
  Future<List<CustomerReservation>> build() async {
    final service = ref.watch(reservationServiceProvider);
    ref.onDispose(_unsubscribe);

    final userId = _tryCurrentUserId();
    if (userId != null) {
      _subscribeToUpdates(userId);
    }

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
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(reservationServiceProvider).getMyReservations(),
    );
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