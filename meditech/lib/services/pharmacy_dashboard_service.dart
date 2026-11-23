
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
        .select(
          'id, reference_no, status, submitted_at, total_amount, '
          'confirmed_at, expires_at',
        );

    return List<Map<String, dynamic>>.from(result);
  }

  /// Pending reservations for the dashboard list (oldest first, max 5).
  Future<List<Map<String, dynamic>>> loadPendingRequests() async {
    List<dynamic> result;
    try {
      result = await _client
          .from('reservations')
          .select('''
          id,
          reference_no,
          has_rx,
          submitted_at,
          accounts!customer_id (
            customer_profiles (first_name, last_name)
          ),
          reservation_items (
            line_no, brand_name, quantity
          )
        ''')
          .eq('status', 'pending')
          .order('submitted_at', ascending: true)
          .limit(5);
    } on PostgrestException {
      result = await _client
          .from('reservations')
          .select('''
          id,
          reference_no,
          has_rx,
          submitted_at,
          reservation_items (
            line_no, brand_name, quantity
          )
        ''')
          .eq('status', 'pending')
          .order('submitted_at', ascending: true)
          .limit(5);
    }

    return result.map((row) {
      final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
      var profile = map['customer_profiles'] as Map<String, dynamic>?;
      profile ??= (map['accounts'] as Map<String, dynamic>?)?['customer_profiles']
          as Map<String, dynamic>?;
      if (profile != null) {
        final f = profile['first_name'] as String? ?? '';
        final l = profile['last_name'] as String? ?? '';
        map['customer_name'] = '$f $l'.trim();
      } else {
        map['customer_name'] = 'Customer';
      }
      final items = (map['reservation_items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      items.sort(
        (a, b) =>
            ((a['line_no'] as num?) ?? 0).compareTo((b['line_no'] as num?) ?? 0),
      );
      if (items.isNotEmpty) {
        final first = items.first;
        final brand = first['brand_name'] as String? ?? 'Medicine';
        final qty = (first['quantity'] as num?)?.toInt() ?? 0;
        map['line_summary'] = '$brand × $qty';
      } else {
        map['line_summary'] = 'Items pending';
      }
      return map;
    }).toList();
  }

  /// Short subtitles under each reservation stat card.
  Map<String, String> reservationStatSubtitles(
    List<Map<String, dynamic>> reservations,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    var confirmedYesterday = 0;
    var readyNearingDeadline = 0;
    var completed = 0;
    var closed = 0;

    for (final row in reservations) {
      final status = row['status'] as String? ?? '';
      if (status == 'confirmed') {
        final at = DateTime.tryParse(row['confirmed_at']?.toString() ?? '');
        if (at != null &&
            !at.isBefore(yesterdayStart) &&
            at.isBefore(todayStart)) {
          confirmedYesterday++;
        }
      }
      if (status == 'ready_for_pickup') {
        final expires =
            DateTime.tryParse(row['expires_at']?.toString() ?? '');
        if (expires != null && expires.difference(now).inHours <= 48) {
          readyNearingDeadline++;
        }
      }
      if (status == 'completed') {
        completed++;
      }
      if (status == 'rejected' ||
          status == 'cancelled' ||
          status == 'expired') {
        closed++;
      }
    }

    final fulfillmentDenom = completed + closed;
    final fulfillmentPct = fulfillmentDenom == 0
        ? 0
        : ((completed / fulfillmentDenom) * 100).round();

    return {
      'pending': 'Needs attention',
      'confirmed': confirmedYesterday == 0
          ? 'No new confirmations yesterday'
          : '+$confirmedYesterday from yesterday',
      'ready_for_pickup': readyNearingDeadline == 0
          ? 'On track'
          : '$readyNearingDeadline nearing deadline',
      'completed': fulfillmentPct == 0
          ? 'No completed pickups yet'
          : '$fulfillmentPct% fulfillment',
    };
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

  /// Inventory rows shown on the dashboard (mockup subset).
  Map<String, int> inventorySnapshotForDashboard(Map<String, int> full) {
    return {
      'active_listings': full['active_listings'] ?? 0,
      'low_stock': full['low_stock'] ?? 0,
      'marked_out_of_stock': full['marked_out_of_stock'] ?? 0,
      'unavailable': full['unavailable'] ?? 0,
      'unconfirmed': full['unconfirmed'] ?? 0,
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
      loadPendingRequests(),
    ]);

    final reservations = results[0] as List<Map<String, dynamic>>;
    final inventory = results[1] as List<Map<String, dynamic>>;
    final pendingRequests = results[2] as List<Map<String, dynamic>>;
    final snapshot = inventorySnapshot(inventory);

    return {
      'reservation_counts': countReservations(reservations),
      'reservation_subtitles': reservationStatSubtitles(reservations),
      'oldest_pending': pendingRequests.isNotEmpty
          ? pendingRequests
          : oldestPendingReservations(reservations),
      'inventory_snapshot': inventorySnapshotForDashboard(snapshot),
    };
  }
}
