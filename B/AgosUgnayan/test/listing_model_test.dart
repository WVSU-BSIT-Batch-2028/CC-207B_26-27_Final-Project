// Unit tests for the models: reading Firestore data with missing fields must
// never crash, and BuyerRequest.isClosed follows the needed-by date.

import 'package:agosugnayan/models/buyer_request.dart';
import 'package:agosugnayan/models/listing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Listing.fromMap fills safe defaults for missing fields', () {
    final listing = Listing.fromMap('abc', {'crop': 'Tomato', 'price': 45});
    expect(listing.id, 'abc');
    expect(listing.crop, 'Tomato');
    expect(listing.price, 45.0);
    expect(listing.quantity, 0);
    expect(listing.unit, 'kg');
    expect(listing.harvestDate, isNull);
    expect(listing.aiAssisted, isFalse);
  });

  BuyerRequest requestNeededBy(DateTime date) {
    return BuyerRequest.fromMap('r1', {
      'crop': 'Onion',
      'neededBy': Timestamp.fromDate(date),
    });
  }

  test('a request needed yesterday is closed', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(requestNeededBy(yesterday).isClosed, isTrue);
  });

  test('a request needed today is still open', () {
    expect(requestNeededBy(DateTime.now()).isClosed, isFalse);
  });
}
