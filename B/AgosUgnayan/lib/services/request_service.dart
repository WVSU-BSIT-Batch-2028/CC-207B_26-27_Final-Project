// Reads and writes buyer requests in Firestore (requests collection).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/buyer_request.dart';
import '../utils/app_exception.dart';

/// Create, read, update and delete buyer requests.
class RequestService {
  CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('requests');

  /// The logged-in buyer's own requests, newest first.
  Future<List<BuyerRequest>> fetchByBuyer(String buyerId) {
    return runSafely('load my requests', () async {
      final snapshot = await _requests
          .where('buyerId', isEqualTo: buyerId)
          .get();
      final requests = snapshot.docs
          .map((doc) => BuyerRequest.fromMap(doc.id, doc.data()))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  /// Open requests for the farmers' Buyer Demand tab: needed today or later,
  /// soonest first. [limit] keeps the list from growing without end.
  Future<List<BuyerRequest>> fetchOpen({int limit = 100}) {
    return runSafely('load buyer demand', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = await _requests
          .where('neededBy', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('neededBy')
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => BuyerRequest.fromMap(doc.id, doc.data()))
          // Requests the buyer closed are not shown to farmers.
          .where((request) => !request.closedByBuyer)
          .toList();
    });
  }

  /// Adds a new request (when id is empty) or updates an existing one.
  Future<void> save(BuyerRequest request) {
    return runSafely('save request', () async {
      if (request.id.isEmpty) {
        await _requests.add({
          ...request.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _requests.doc(request.id).update(request.toMap());
      }
    });
  }

  /// Closes a request (the buyer found what they needed) or opens it
  /// again. Farmers no longer see closed requests in Buyer Demand.
  Future<void> setClosed(String id, bool closed) {
    return runSafely(
      'close request',
      () => _requests.doc(id).update({'closed': closed}),
    );
  }

  Future<void> delete(String id) {
    return runSafely('delete request', () => _requests.doc(id).delete());
  }

  /// Puts a deleted request back exactly as it was (for the Undo button).
  Future<void> restore(BuyerRequest request) {
    return runSafely('restore request', () {
      return _requests.doc(request.id).set({
        ...request.toMap(),
        'createdAt': Timestamp.fromDate(request.createdAt),
      });
    });
  }
}
