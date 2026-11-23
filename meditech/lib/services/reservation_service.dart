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

  static const _listSelect = '''
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
        ''';

  // Loads all reservations belonging to the signed-in customer, newest first
  Future<List<CustomerReservation>> getMyReservations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    try {
      final rows = await _client
          .from('reservations')
          .select(_listSelect)
          .eq('customer_id', userId)
          .order('submitted_at', ascending: false);

      return (rows as List<dynamic>)
          .map(
            (row) => CustomerReservation.fromJson(row as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (error) {
      // If branch embed fails (RLS / schema), still return reservations with generic pharmacy labels.
      if (error.code != 'PGRST200' &&
          !error.message.toLowerCase().contains('branches')) {
        rethrow;
      }
      return _loadMyReservationsWithoutBranchEmbed(userId);
    }
  }

  Future<List<CustomerReservation>> _loadMyReservationsWithoutBranchEmbed(
    String userId,
  ) async {
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

    final branchNames = await _branchLabelsForRows(rows as List<dynamic>);

    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final branchId = map['branch_id'] as String?;
      map['branches'] = branchId != null ? branchNames[branchId] : null;
      return CustomerReservation.fromJson(map);
    }).toList();
  }

  Future<Map<String, Map<String, String>>> _branchLabelsForRows(
    List<dynamic> rows,
  ) async {
    final ids = rows
        .map((r) => (r as Map<String, dynamic>)['branch_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return {};

    final pub = await _client
        .from('public_branches')
        .select('id, pharmacy_name, branch_name, address')
        .inFilter('id', ids);

    return {
      for (final row in pub as List<dynamic>)
        (row as Map<String, dynamic>)['id'] as String: {
          'pharmacy_name': row['pharmacy_name'] as String? ?? 'Pharmacy',
          'branch_name': row['branch_name'] as String? ?? '',
          'address': row['address'] as String? ?? '',
        },
    };
  }

  // Cancels the signed-in customer's own pending reservation
  Future<void> cancelMyReservation(String reservationId) async {
    await _client.rpc(
      'customer_cancel_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  // Loads a single reservation with full details, pickup code, and timeline
  Future<CustomerReservation?> getReservationById(String reservationId) async {
    const fullSelect = '''
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
        ''';

    try {
      final row = await _client
          .from('reservations')
          .select(fullSelect)
          .eq('id', reservationId)
          .maybeSingle();

      if (row == null) return null;
      return CustomerReservation.fromJson(row);
    } on PostgrestException {
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
      final map = Map<String, dynamic>.from(row);
      final branchId = map['branch_id'] as String?;
      if (branchId != null) {
        final pub = await _client
            .from('public_branches')
            .select('pharmacy_name, branch_name, address')
            .eq('id', branchId)
            .maybeSingle();
        map['branches'] = pub;
      }
      return CustomerReservation.fromJson(map);
    }
  }
}