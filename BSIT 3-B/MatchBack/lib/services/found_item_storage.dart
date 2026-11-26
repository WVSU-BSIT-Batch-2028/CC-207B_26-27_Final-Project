import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/found_item.dart';
import 'report_image_storage.dart';
import 'firestore_data.dart';

class FoundItemStorage {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('found_reports');

  final CollectionReference<Map<String, dynamic>> _privateCollection =
      FirebaseFirestore.instance.collection('found_report_private');

  /// Saves the report. If [image] is given, the report and its photo are
  /// saved together: either both succeed or neither does.
  Future<void> save(FoundItem item, {ReportImageData? image}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    final batch = FirebaseFirestore.instance.batch();

    batch.set(_collection.doc(item.id), {
      ...item.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Storage location is operational information for staff. It must never be
    // part of a report that every signed-in student can read.
    batch.set(_privateCollection.doc(item.id), {
      'storageLocation': item.storageLocation,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (image != null) {
      ReportImageStorage.addToBatch(
        batch,
        type: 'found',
        reportId: item.id,
        image: image,
      );
    }

    await batch.commit();
  }

  Future<List<FoundItem>> loadAll() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((document) => FoundItem.fromJson(withTimestamps(document.data())))
        .toList();
  }
}
