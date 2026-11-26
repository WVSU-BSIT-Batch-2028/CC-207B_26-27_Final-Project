import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/claim_request.dart';
import '../models/notification_record.dart';
import 'firestore_data.dart';

class NotificationStorage {
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('notifications');

  /// Staff only. Records one contact attempt. The time comes from the
  /// server, and the rules require the signed-in user to be staff.
  Future<void> record({
    required ClaimRequest claim,
    required String event,
    required String method,
    required String outcome,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    await _collection.add({
      'claimId': claim.id,
      'foundItemId': claim.foundItemId,
      'studentId': claim.studentId,
      'ownerUid': claim.ownerUid,
      'event': event,
      'method': method,
      'outcome': outcome,
      'byUid': uid,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Staff view: every attempt for one claim, newest first.
  Future<List<NotificationRecord>> loadForClaim(String claimId) async {
    final snapshot = await _collection
        .where('claimId', isEqualTo: claimId)
        .get();
    return _toSortedList(snapshot);
  }

  /// Student view: only the attempts about this signed-in student's own claims.
  Future<List<NotificationRecord>> loadForCurrentStudent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    final snapshot = await _collection
        .where('ownerUid', isEqualTo: uid)
        .get();
    return _toSortedList(snapshot);
  }

  // Sorted here so no extra Firestore index is needed.
  List<NotificationRecord> _toSortedList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final records = snapshot.docs
        .map(
          (doc) => NotificationRecord.fromJson({
            ...withTimestamps(doc.data()),
            'id': doc.id,
          }),
        )
        .toList();

    records.sort(
      (a, b) => (b.sentAt ?? DateTime(0)).compareTo(a.sentAt ?? DateTime(0)),
    );
    return records;
  }
}
