// Farmers' own crop photos, saved in Firestore at listing_photos/{listingId}
// (we have no Firebase Storage on the free plan). Each photo has its own
// document, so loading the Market list does not download every photo.
// Photos are kept in memory after the first load.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_logger.dart';

/// Loads farmers' photos. There is one shared instance, so the memory
/// cache is shared by every card.
class ListingPhotoService {
  ListingPhotoService._();

  static final ListingPhotoService instance = ListingPhotoService._();

  /// Listing id -> its photo (or null when it has none). Saving the Future
  /// means two cards asking at the same time share one download.
  final Map<String, Future<Uint8List?>> _cache = {};

  static CollectionReference<Map<String, dynamic>> get collection =>
      FirebaseFirestore.instance.collection('listing_photos');

  /// The farmer's photo for [listingId], or null when there is none or it
  /// could not load (the card then shows the sample photo).
  Future<Uint8List?> photoFor(String listingId) {
    return _cache.putIfAbsent(listingId, () async {
      try {
        final doc = await collection.doc(listingId).get();
        final data = doc.data()?['data'] as String?;
        return data == null ? null : base64Decode(data);
      } catch (e) {
        AppLogger.error('load listing photo failed', e);
        _cache.remove(listingId); // try again next time
        return null;
      }
    });
  }

  /// The fields we save for a photo (used inside ListingService's batch).
  static Map<String, dynamic> toMap(String farmerId, Uint8List jpeg) => {
    'farmerId': farmerId,
    'data': base64Encode(jpeg),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Remembers a photo we just saved (or null after removing it), so the
  /// screens show the new one right away without downloading it.
  void remember(String listingId, Uint8List? jpeg) {
    _cache[listingId] = Future.value(jpeg);
  }
}
