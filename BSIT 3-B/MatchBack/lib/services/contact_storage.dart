import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/contact_details.dart';

/// Contact details live in their own protected collection, never inside a
/// public report or a claim. Firestore rules let only staff read them.
class ContactStorage {
  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('contact_details');

  /// Adds the contact document to a batch so it is saved together with the
  /// report or claim it belongs to. [kind] is 'lost' or 'claim'.
  static void addToBatch(
    WriteBatch batch, {
    required String kind,
    required String refId,
    required ContactDetails contact,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    batch.set(_collection.doc('${kind}_$refId'), {
      ...contact.toJson(),
      'kind': kind,
      'refId': refId,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Staff only. Returns null when no contact details were saved, for
  /// example for reports made before this feature existed.
  static Future<ContactDetails?> load(String kind, String refId) async {
    final doc = await _collection.doc('${kind}_$refId').get();
    final data = doc.data();
    if (data == null) return null;
    return ContactDetails.fromJson(data);
  }
}
