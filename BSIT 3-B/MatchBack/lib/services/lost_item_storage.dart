import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/lost_item.dart';
import '../models/contact_details.dart';
import 'contact_storage.dart';
import 'report_image_storage.dart';
import 'firestore_data.dart';

class LostItemStorage {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('lost_reports');

  final CollectionReference<Map<String, dynamic>> _privateCollection =
      FirebaseFirestore.instance.collection('lost_report_private');

  /// Saves the public report, its protected private detail, and the optional
  /// photo together: either all succeed or none do.
  Future<void> save(
    LostItem item, {
    required ContactDetails contact,
    ReportImageData? image,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    final batch = FirebaseFirestore.instance.batch();

    batch.set(_collection.doc(item.id), {
      ...item.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_privateCollection.doc(item.id), {
      'privateDetail': item.privateDetail,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Contact details go in their own staff-only collection.
    ContactStorage.addToBatch(
      batch,
      kind: 'lost',
      refId: item.id,
      contact: contact,
    );

    if (image != null) {
      ReportImageStorage.addToBatch(
        batch,
        type: 'lost',
        reportId: item.id,
        image: image,
      );
    }

    await batch.commit();
  }

  /// Staff only: the protected private detail for one report.
  /// Returns null if none was saved (for example, older reports).
  Future<String?> loadPrivateDetail(String reportId) async {
    final doc = await _privateCollection.doc(reportId).get();
    return doc.data()?['privateDetail'] as String?;
  }

  Future<List<LostItem>> loadAll() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((document) => LostItem.fromJson(withTimestamps(document.data())))
        .toList();
  }
}
