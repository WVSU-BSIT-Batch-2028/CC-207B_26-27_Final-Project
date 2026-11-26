import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/claim_request.dart';
import '../models/contact_details.dart';
import 'contact_storage.dart';
import 'firestore_data.dart';

class ClaimStorage {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('claim_requests');

  /// Saves the claim and the claimant's protected contact details together:
  /// either both succeed or neither does.
  Future<void> save(
    ClaimRequest claim, {
    required ContactDetails contact,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.set(_collection.doc(claim.id), {
      ...claim.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    ContactStorage.addToBatch(
      batch,
      kind: 'claim',
      refId: claim.id,
      contact: contact,
    );

    await batch.commit();
  }

  /// All claims. Only staff are allowed to do this.
  Future<List<ClaimRequest>> loadAll() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => ClaimRequest.fromJson(withTimestamps(document.data())),
        )
        .toList();
  }

  /// Only the claims owned by the signed-in student. Querying by the Firebase
  /// user ID lets the Firestore rule prove that every returned claim is theirs.
  Future<List<ClaimRequest>> loadForCurrentStudent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    final snapshot = await _collection
        .where('ownerUid', isEqualTo: uid)
        .get();

    final claims = snapshot.docs
        .map(
          (document) => ClaimRequest.fromJson(withTimestamps(document.data())),
        )
        .toList();

    // Newest first. Sorted here so no extra Firestore index is needed.
    claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return claims;
  }

  /// True when the signed-in student already has a claim on the item that is still
  /// being handled (pending, approved or ready). Rejected claims don't count.
  Future<bool> hasOpenClaim(String foundItemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    final snapshot = await _collection
        .where('ownerUid', isEqualTo: uid)
        .where('foundItemId', isEqualTo: foundItemId)
        .get(const GetOptions(source: Source.server));

    const openStatuses = ['pending', 'approved', 'ready'];
    return snapshot.docs.any(
      (doc) => openStatuses.contains(doc.data()['status']),
    );
  }

  /// Moves a claim one step forward and keeps the found item in step with it.
  /// The allowed steps are:
  ///   pending  -> approved or rejected
  ///   approved -> ready       (item is waiting at the office)
  ///   ready    -> returned    (item was physically handed over)
  /// Everything happens in one transaction, so the claim, the item and the
  /// history entry are saved together or not at all. The times come from the
  /// server clock, so they record when staff really took the step.
  Future<void> advance(ClaimRequest claim, String toStatus) async {
    final staffUid = FirebaseAuth.instance.currentUser?.uid;
    if (staffUid == null) throw StateError('not-signed-in');

    final db = FirebaseFirestore.instance;
    final claimRef = _collection.doc(claim.id);
    final itemRef = db.collection('found_reports').doc(claim.foundItemId);
    final eventRef = db.collection('status_events').doc();

    await db.runTransaction((transaction) async {
      // Read the current values from the server first. A screen that was
      // open for a while cannot approve the same item twice or skip a step.
      final claimSnap = await transaction.get(claimRef);
      final itemSnap = await transaction.get(itemRef);
      final from = claimSnap.data()?['status'] as String?;
      final itemStatus = itemSnap.data()?['status'] as String?;
      if (from == null || itemStatus == null) {
        throw StateError('missing-record');
      }

      final now = FieldValue.serverTimestamp();
      final claimChanges = <String, dynamic>{'status': toStatus};
      Map<String, dynamic>? itemChanges;

      if (toStatus == 'approved' && from == 'pending') {
        // Only one claim can be approved for an item.
        if (itemStatus != 'found') throw StateError('item-unavailable');
        claimChanges['approvedAt'] = now;
        itemChanges = {'status': 'claim_pending'};
      } else if (toStatus == 'rejected' && from == 'pending') {
        claimChanges['rejectedAt'] = now;
      } else if (toStatus == 'ready' && from == 'approved') {
        claimChanges['readyAt'] = now;
        itemChanges = {'status': 'ready', 'readyAt': now};
      } else if (toStatus == 'returned' && from == 'ready') {
        claimChanges['returnedAt'] = now;
        itemChanges = {'status': 'returned', 'returnedAt': now};
      } else {
        throw StateError('invalid-step');
      }

      transaction.update(claimRef, claimChanges);
      if (itemChanges != null) transaction.update(itemRef, itemChanges);

      // One history entry per step, so staff can see who did what and when.
      transaction.set(eventRef, {
        'kind': 'claim',
        'claimId': claim.id,
        'foundItemId': claim.foundItemId,
        'fromStatus': from,
        'toStatus': toStatus,
        'byUid': staffUid,
        'at': now,
      });
    });
  }
}
