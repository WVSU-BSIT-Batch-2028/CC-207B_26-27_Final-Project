
import 'package:supabase_flutter/supabase_flutter.dart';

class PharmacyDashboardService {
  PharmacyDashboardService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  /// Loads reservation data visible to the signed-in pharmacy branch.
  /// Branch access is enforced by the database RLS policies.
  Future<List<Map<String, dynamic>>> loadReservations() async {
    final result = await _client
        .from('reservations')
        .select('id, reference_no, status, submitted_at, total_amount');

    return List<Map<String, dynamic>>.from(result);
  }

  /// Loads the inventory data visible to the signed-in pharmacy branch.
  Future<List<Map<String, dynamic>>> loadInventory() async {
    final result = await _client.from('inventory_items').select(
          'id, stock_quantity, held_quantity, low_stock_threshold, '
          'nearest_expiry, out_of_stock_flag, is_active, stock_confirmed_at',
        );

    return List<Map<String, dynamic>>.from(result);
  }

  /// Returns the number of reservations for each dashboard status.
  Map<String, int> countReservations(
    List<Map<String, dynamic>> reservations,
  ) {
    return {
      'pending': _countStatus(reservations, 'pending'),
      'confirmed': _countStatus(reservations, 'confirmed'),
      'ready_for_pickup':
          _countStatus(reservations, 'ready_for_pickup'),
      'completed': _countStatus(reservations, 'completed'),
    };
  }

  int _countStatus(
    List<Map<String, dynamic>> reservations,
    String status,
  ) {
    return reservations
        .where((reservation) => reservation['status'] == status)
        .length;
  }

  /// Returns the five oldest pending reservations.
  List<Map<String, dynamic>> oldestPendingReservations(
    List<Map<String, dynamic>> reservations,
  ) {
    final pending = reservations
        .where((reservation) => reservation['status'] == 'pending')
        .toList();

    pending.sort((a, b) {
      final aDate = DateTime.tryParse(a['submitted_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['submitted_at']?.toString() ?? '');

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return pending.take(5).toList();
  }

  /// Calculates the inventory snapshot shown on the dashboard.
  Map<String, int> inventorySnapshot(
    List<Map<String, dynamic>> inventory,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryLimit = today.add(const Duration(days: 60));
    final unconfirmedLimit = now.subtract(const Duration(days: 7));

    var activeListings = 0;
    var lowStock = 0;
    var markedOutOfStock = 0;
    var unavailable = 0;
    var unconfirmed = 0;
    var expiringWithin60Days = 0;

    for (final item in inventory) {
      final isActive = item['is_active'] == true;
      final isMarkedOutOfStock = item['out_of_stock_flag'] == true;

      final stockQuantity = _asInt(item['stock_quantity']);
      final heldQuantity = _asInt(item['held_quantity']);
      final threshold = _asInt(item['low_stock_threshold']);
      final availableQuantity = stockQuantity - heldQuantity;

      final confirmedAt =
          DateTime.tryParse(item['stock_confirmed_at']?.toString() ?? '');

      final expiry =
          DateTime.tryParse(item['nearest_expiry']?.toString() ?? '');

      if (isActive) {
        activeListings++;
      }

      if (isMarkedOutOfStock) {
        markedOutOfStock++;
      }

      if (isMarkedOutOfStock || availableQuantity <= 0) {
        unavailable++;
      }

      if (!isMarkedOutOfStock &&
          availableQuantity > 0 &&
          availableQuantity <= threshold) {
        lowStock++;
      }

      if (confirmedAt == null || confirmedAt.isBefore(unconfirmedLimit)) {
        unconfirmed++;
      }

      if (expiry != null &&
          !expiry.isBefore(today) &&
          !expiry.isAfter(expiryLimit)) {
        expiringWithin60Days++;
      }
    }

    return {
      'active_listings': activeListings,
      'low_stock': lowStock,
      'marked_out_of_stock': markedOutOfStock,
      'unavailable': unavailable,
      'unconfirmed': unconfirmed,
      'expiring_within_60_days': expiringWithin60Days,
    };
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Loads all dashboard data in parallel.
  Future<Map<String, dynamic>> loadDashboard() async {
    final results = await Future.wait([
      loadReservations(),
      loadInventory(),
    ]);

    final reservations = results[0];
    final inventory = results[1];

    return {
      'reservation_counts': countReservations(reservations),
      'oldest_pending': oldestPendingReservations(reservations),
      'inventory_snapshot': inventorySnapshot(inventory),
    };
  }
}
