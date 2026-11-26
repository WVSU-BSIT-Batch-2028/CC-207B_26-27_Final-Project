// Tests for the stock math (available / reserved / sold) and for order
// states, including expiry worked out from the dates.

import 'package:agosugnayan/models/listing.dart';
import 'package:agosugnayan/models/order.dart';
import 'package:agosugnayan/screens/orders_screen.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 23, 10);

Listing _pechay({double sold = 0, List<Reservation> reservations = const []}) =>
    Listing(
      id: 'p1',
      farmerId: 'f',
      farmerName: 'Juan',
      crop: 'Pechay',
      quantity: 20,
      unit: 'kg',
      price: 54.4,
      town: 'Leon',
      harvestDate: null,
      description: '',
      aiAssisted: false,
      createdAt: now,
      soldQty: sold,
      reservations: reservations,
    );

Reservation _hold(double qty, Duration fromNow) =>
    Reservation(orderId: 'o$qty', qty: qty, until: now.add(fromNow));

CropOrder _order(String status, {DateTime? created, DateTime? until}) =>
    CropOrder(
      id: 'o1',
      source: OrderSource.listing,
      listingId: 'p1',
      farmerId: 'f',
      farmerName: 'Juan',
      buyerId: 'b',
      buyerName: 'Ana',
      chatId: 'b_f',
      crop: 'Pechay',
      title: '',
      unit: 'kg',
      qty: 5,
      price: 54.4,
      note: '',
      status: status,
      createdAt: created ?? now,
      reservedUntil: until,
    );

void main() {
  group('stock', () {
    test('a new listing has everything available', () {
      final p = _pechay();
      expect(p.availableAt(now), 20);
      expect(p.reservedAt(now), 0);
      expect(p.stockAt(now), StockState.available);
    });

    test('20 kg, 5 kg reserved for a buyer: 15 kg available', () {
      final p = _pechay(reservations: [_hold(5, const Duration(days: 3))]);
      expect(p.reservedAt(now), 5);
      expect(p.availableAt(now), 15);
    });

    test('an ended reservation stops counting by itself', () {
      final p = _pechay(
        reservations: [
          _hold(5, const Duration(days: 3)),
          _hold(4, const Duration(hours: -1)), // ended an hour ago
        ],
      );
      expect(p.reservedAt(now), 5);
      expect(p.availableAt(now), 15);
    });

    test('sold and reserved both come off the available amount', () {
      final p = _pechay(
        sold: 5,
        reservations: [_hold(15, const Duration(days: 1))],
      );
      expect(p.availableAt(now), 0);
      expect(p.stockAt(now), StockState.fullyReserved);
      // When the hold ends, the 15 kg are free again.
      expect(p.availableAt(now.add(const Duration(days: 2))), 15);
    });

    test('everything sold is sold out, and never below zero', () {
      final p = _pechay(sold: 20);
      expect(p.stockAt(now), StockState.soldOut);
      expect(_pechay(sold: 25).availableAt(now), 0);
    });

    test('stock fields are read from Firestore, with old listings at 0', () {
      final p = Listing.fromMap('p', {
        'quantity': 20,
        'soldQty': 3,
        'reservations': [
          {'orderId': 'x', 'qty': 2, 'until': now.add(const Duration(days: 1))},
        ],
      });
      expect(p.soldQty, 3);
      expect(p.reservationFor('x')?.qty, 2);
      expect(Listing.fromMap('q', {'quantity': 5}).soldQty, 0);
    });
  });

  group('orders', () {
    test('the total is quantity times price in centavos', () {
      expect(orderTotal(5, 54.4), 272.0);
      expect(orderTotal(0.5, 33.33), 16.67);
      expect(_order(OrderStatus.pending).total, 272.0);
    });

    test('a request waits 3 days, then expires', () {
      final order = _order(OrderStatus.pending);
      expect(order.stateAt(now), OrderState.pending);
      expect(
        order.stateAt(now.add(const Duration(days: 2, hours: 23))),
        OrderState.pending,
      );
      expect(
        order.stateAt(now.add(const Duration(days: 3))),
        OrderState.expired,
      );
    });

    test('a reservation shows as ended after its date', () {
      final order = _order(
        OrderStatus.reserved,
        until: now.add(const Duration(days: 3)),
      );
      expect(order.stateAt(now), OrderState.reserved);
      expect(
        order.stateAt(now.add(const Duration(days: 4))),
        OrderState.holdEnded,
      );
    });

    test('finished orders never expire', () {
      final old = now.subtract(const Duration(days: 30));
      expect(
        _order(OrderStatus.completed, created: old).stateAt(now),
        OrderState.completed,
      );
      expect(
        _order(OrderStatus.declined, created: old).stateAt(now),
        OrderState.declined,
      );
    });

    test('each state goes in the right Orders tab', () {
      expect(tabOf(OrderState.pending), OrdersTab.waiting);
      expect(tabOf(OrderState.offered), OrdersTab.waiting);
      expect(tabOf(OrderState.holdEnded), OrdersTab.reserved);
      expect(tabOf(OrderState.completed), OrdersTab.sold);
      expect(tabOf(OrderState.expired), OrdersTab.closed);
    });

    test('the saved order lists both people for the rules', () {
      final map = _order(OrderStatus.pending).toMap();
      expect(map['participants'], ['b', 'f']);
      expect(map['total'], 272.0);
    });
  });
}
