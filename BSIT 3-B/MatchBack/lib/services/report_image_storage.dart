import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportImageData {
  const ReportImageData(this.bytes, this.mime);

  final Uint8List bytes;
  final String mime;
}

class ReportImageStorage {
  // Photos already downloaded, so scrolling and filtering stay fast.
  static final Map<String, ReportImageData> _cache = {};

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('report_images');

  /// [type] is 'lost' or 'found'.
  static String docId(String type, String reportId) => '${type}_$reportId';

  /// Adds the photo to a batch so it is saved together with its report.
  static void addToBatch(
    WriteBatch batch, {
    required String type,
    required String reportId,
    required ReportImageData image,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('not-signed-in');

    batch.set(_collection.doc(docId(type, reportId)), {
      'type': type,
      'reportId': reportId,
      'mime': image.mime,
      'data': base64Encode(image.bytes),
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns the photo for a report, or null if it has none.
  static Future<ReportImageData?> load(String type, String reportId) async {
    final id = docId(type, reportId);

    final cached = _cache[id];
    if (cached != null) return cached;

    final doc = await _collection.doc(id).get();
    final data = doc.data();
    if (data == null) return null;

    final image = ReportImageData(
      base64Decode(data['data'] as String),
      data['mime'] as String,
    );
    _cache[id] = image;
    return image;
  }
}
