// Follow and unfollow crop listings and farmers. Each followed item is saved
// at users/{myId}/following/{targetId}, so every user only sees their own.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/followed_item.dart';
import '../utils/app_exception.dart';

/// Following for the logged-in user.
class FollowingService {
  CollectionReference<Map<String, dynamic>> _following(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('following');
  }

  /// Everything of one [type] the user follows, newest first.
  Future<List<FollowedItem>> fetch(String userId, String type) {
    return runSafely('load following', () async {
      final snapshot = await _following(userId)
          .where('type', isEqualTo: type)
          .get();
      final items = snapshot.docs
          .map((doc) => FollowedItem.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// True if the user already follows [targetId].
  Future<bool> isFollowing(String userId, String targetId) {
    return runSafely('check following', () async {
      final doc = await _following(userId).doc(targetId).get();
      return doc.exists;
    });
  }

  Future<void> follow({
    required String userId,
    required String targetId,
    required String type,
    required String title,
    required String subtitle,
  }) {
    return runSafely('follow', () {
      return _following(userId).doc(targetId).set({
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> unfollow(String userId, String targetId) {
    return runSafely(
      'unfollow',
      () => _following(userId).doc(targetId).delete(),
    );
  }
}
