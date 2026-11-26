import 'package:flutter_test/flutter_test.dart';
import 'package:matchback/models/claim_request.dart';
import 'package:matchback/models/found_item.dart';
import 'package:matchback/utils/status_labels.dart';

// Checks the workflow wording and timestamps. No Firebase is needed.
void main() {
  test('claim statuses have clear labels', () {
    expect(claimStatusLabel('pending'), 'Pending Review');
    expect(claimStatusLabel('ready'), 'Ready for Collection');
    expect(claimStatusLabel('returned'), 'Returned to Owner');
  });

  test('item statuses have clear labels, including the old claimed status', () {
    expect(itemStatusLabel('claim_pending'), 'Claim Pending');
    expect(itemStatusLabel('claimed'), 'Claim Approved');
    expect(itemStatusLabel('returned'), 'Returned to Owner');
  });

  test('ClaimRequest reads workflow times and leaves missing ones null', () {
    final claim = ClaimRequest.fromJson({
      'id': '1',
      'foundItemId': '2',
      'foundItemName': 'Phone',
      'claimantName': 'Sam',
      'reason': 'It is my phone',
      'privateDetail': 'Sticker on the back',
      'status': 'approved',
      'submittedAt': '2026-10-26T10:00:00.000',
      'approvedAt': '2026-10-27T02:00:00.000Z',
    });

    expect(claim.approvedAt, DateTime.utc(2026, 10, 27, 2));
    expect(claim.readyAt, isNull);
    expect(claim.returnedAt, isNull);
  });

  test('FoundItem reads the return time when it exists', () {
    final item = FoundItem.fromJson({
      'id': '2',
      'category': 'Electronics',
      'name': 'Phone',
      'description': 'Black phone with a cracked screen',
      'locationFound': 'Gym',
      'dateFound': '10/22/2026',
      'storageLocation': 'Guard house',
      'status': 'returned',
      'returnedAt': '2026-10-27T06:15:00.000Z',
    });

    expect(item.returnedAt, DateTime.utc(2026, 10, 27, 6, 15));
    expect(item.readyAt, isNull);
  });
}
