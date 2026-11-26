import 'package:flutter_test/flutter_test.dart';
import 'package:matchback/models/claim_request.dart';
import 'package:matchback/models/found_item.dart';
import 'package:matchback/models/lost_item.dart';

// These tests check the data models only, so they need no Firebase.
void main() {
  group('LostItem', () {
    final item = LostItem(
      id: '1',
      category: 'Bag',
      name: 'Blue backpack',
      description: 'Blue backpack with a keychain',
      location: 'Library',
      dateLost: '10/20/2026',
      privateDetail: 'Has a torn lining',
      status: 'lost',
    );

    test('toJson never includes the private detail', () {
      // The private detail is saved in a separate protected document.
      expect(item.toJson().containsKey('privateDetail'), isFalse);
    });

    test(
      'fromJson loads an old report and ignores a leftover private detail',
      () {
        final loaded = LostItem.fromJson({
          'id': '2',
          'category': 'Bottle',
          'name': 'Water bottle',
          'description': 'Black bottle',
          'location': 'Canteen',
          'dateLost': '10/21/2026',
          'status': 'lost',
          'privateDetail': 'old secret saved before the privacy change',
        });

        expect(loaded.hasImage, isFalse);
        expect(loaded.privateDetail, '');
      },
    );
  });

  group('FoundItem', () {
    test('copyWith changes only the status', () {
      final item = FoundItem(
        id: '3',
        category: 'Electronics',
        name: 'Phone',
        description: 'Black phone with a cracked screen',
        locationFound: 'Gym',
        dateFound: '10/22/2026',
        storageLocation: 'Guard house',
        status: 'found',
        hasImage: true,
      );

      final updated = item.copyWith(status: 'claimed');

      expect(updated.status, 'claimed');
      expect(updated.hasImage, isTrue);
      expect(updated.name, 'Phone');
    });
  });

  group('ClaimRequest', () {
    test('fromJson loads an old claim that has no student ID or owner', () {
      final claim = ClaimRequest.fromJson({
        'id': '4',
        'foundItemId': '3',
        'foundItemName': 'Phone',
        'claimantName': 'Sam',
        'reason': 'It is my phone',
        'privateDetail': 'Sticker on the back',
        'status': 'pending',
        'submittedAt': '2026-10-23T10:00:00.000',
      });

      expect(claim.studentId, '');
      expect(claim.ownerUid, '');
    });

    test('toJson and fromJson keep the same data', () {
      final claim = ClaimRequest(
        id: '5',
        foundItemId: '3',
        foundItemName: 'Phone',
        claimantName: 'Sam',
        reason: 'It is my phone',
        privateDetail: 'Sticker on the back',
        status: 'pending',
        submittedAt: '2026-10-23T10:00:00.000',
        studentId: '2023-12345',
        ownerUid: 'abc123',
      );

      final copy = ClaimRequest.fromJson(claim.toJson());

      expect(copy.studentId, '2023-12345');
      expect(copy.ownerUid, 'abc123');
      expect(copy.status, 'pending');
    });
  });
}
