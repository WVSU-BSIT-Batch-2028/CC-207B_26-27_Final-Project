// Unit tests for a buyer request's status (Open / Expired / Closed), which
// is worked out from the dates every time it is read.

import 'package:agosugnayan/models/buyer_request.dart';
import 'package:flutter_test/flutter_test.dart';

BuyerRequest _request(DateTime neededBy, {bool closed = false}) => BuyerRequest(
  id: 'r1',
  buyerId: 'b1',
  buyerName: 'Ana',
  crop: 'Mango',
  quantity: 10,
  unit: 'kg',
  targetPrice: null,
  town: 'Iloilo City',
  neededBy: neededBy,
  notes: '',
  createdAt: DateTime(2026, 11, 1),
  closedByBuyer: closed,
);

void main() {
  // 9 in the evening, so "today" really is a whole day.
  final now = DateTime(2026, 11, 23, 21, 0);

  test('needed today is still open all day', () {
    final r = _request(DateTime(2026, 11, 23));
    expect(r.statusAt(now), RequestStatus.open);
    expect(r.daysLeftAt(now), 0);
  });

  test('needed tomorrow is open, 1 day left', () {
    final r = _request(DateTime(2026, 11, 24, 8));
    expect(r.statusAt(now), RequestStatus.open);
    expect(r.daysLeftAt(now), 1);
  });

  test('needed yesterday is expired', () {
    final r = _request(DateTime(2026, 11, 22, 23, 59));
    expect(r.statusAt(now), RequestStatus.expired);
    expect(r.daysLeftAt(now), -1);
  });

  test('closed stays closed, even when its date passed', () {
    expect(
      _request(DateTime(2026, 11, 20), closed: true).statusAt(now),
      RequestStatus.closed,
    );
    expect(
      _request(DateTime(2026, 12, 1), closed: true).statusAt(now),
      RequestStatus.closed,
    );
  });
}
