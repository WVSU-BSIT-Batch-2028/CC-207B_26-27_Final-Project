import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reservation.dart';

// Talks to Supabase for placing and reading customer reservations
class ReservationService {
  ReservationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Generates a random RFC-4122 v4 UUID for submit_reservation idempotency
  String generateIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  // Places a reservation from the customer's current cart via submit_reservation RPC
  Future<SubmittedReservationResult> submitReservation({
    required String idempotencyKey,
    required bool acknowledged,
  }) async {
    final response = await _client.rpc(
      'submit_reservation',
      params: {
        'p_idempotency_key': idempotencyKey,
        'p_acknowledged': acknowledged,
      },
    );

    if (response is List && response.isNotEmpty) {
      return SubmittedReservationResult.fromJson(
        response.first as Map<String, dynamic>,
      );
    }
    if (response is Map<String, dynamic>) {
      return SubmittedReservationResult.fromJson(response);
    }
    throw StateError('Unexpected response when submitting reservation.');
  }

  // Loads all reservations belonging to the signed-in customer, newest first
  Future<List<CustomerReservation>> getMyReservations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('reservations')
        .select('''
          id,
          reference_no,
          branch_id,
          status,
          has_rx,
          total_amount,
          submitted_at,
          expires_at,
          confirmed_at,
          ready_at,
          completed_at,
          closed_reason,
          updated_at,
          branches ( pharmacy_name, branch_name, address ),
          reservation_items (
            line_no, medicine_id, quantity, brand_name, generic_name,
            strength, dosage_form, unit_sold, is_rx, unit_price
          ),
          pickup_codes ( code_suffix ),
          reservation_status_history (
            id, from_status, to_status, actor_role, reason, created_at
          ),
          reservation_prescriptions (
            id, display_id, storage_path, mime_type, size_bytes, uploaded_at
          )
        ''')
        .eq('customer_id', userId)
        .order('submitted_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => CustomerReservation.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  // Loads a single reservation with full details, pickup code, and timeline
  Future<CustomerReservation?> getReservationById(String reservationId) async {
    final row = await _client
        .from('reservations')
        .select('''
          id,
          reference_no,
          branch_id,
          status,
          has_rx,
          total_amount,
          submitted_at,
          expires_at,
          confirmed_at,
          ready_at,
          completed_at,
          closed_reason,
          updated_at,
          branches ( pharmacy_name, branch_name, address ),
          reservation_items (
            line_no, medicine_id, quantity, brand_name, generic_name,
            strength, dosage_form, unit_sold, is_rx, unit_price
          ),
          pickup_codes ( code_suffix ),
          reservation_status_history (
            id, from_status, to_status, actor_role, reason, created_at
          ),
          reservation_prescriptions (
            id, display_id, storage_path, mime_type, size_bytes, uploaded_at
          )
        ''')
        .eq('id', reservationId)
        .maybeSingle();

    if (row == null) return null;
    return CustomerReservation.fromJson(row);
  }
}