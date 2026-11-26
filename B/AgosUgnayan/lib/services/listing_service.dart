// Reads and writes crop listings in Firestore (listings collection).
// Screens never call Firestore directly; they call this service.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/listing.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import 'listing_photo_service.dart';

/// One page of Marketplace results, plus what we need to load the next page.
class ListingPage {
  const ListingPage(this.listings, this.lastDoc, this.hasMore);

  final List<Listing> listings;
  final DocumentSnapshot? lastDoc; // start the next page after this one
  final bool hasMore; // false when there is nothing more to load
}

/// Create, read, update and delete crop listings.
class ListingService {
  // A getter (not a field) so Firebase is only touched when we really use it.
  CollectionReference<Map<String, dynamic>> get _listings =>
      FirebaseFirestore.instance.collection('listings');

  /// Loads one page of the Marketplace, newest first.
  /// [crop] and [town] are optional filters (null = all).
  /// Pass the previous page's [after] to load the next page.
  Future<ListingPage> fetchPage({
    String? crop,
    String? town,
    DocumentSnapshot? after,
  }) {
    return runSafely('load marketplace', () async {
      Query<Map<String, dynamic>> query = _listings;
      if (crop != null) query = query.where('crop', isEqualTo: crop);
      if (town != null) query = query.where('town', isEqualTo: town);
      query = query.orderBy('createdAt', descending: true).limit(kPageSize);
      if (after != null) query = query.startAfterDocument(after);

      final snapshot = await query.get();
      final listings = snapshot.docs
          .map((doc) => Listing.fromMap(doc.id, doc.data()))
          .toList();
      return ListingPage(
        listings,
        snapshot.docs.isEmpty ? after : snapshot.docs.last,
        snapshot.docs.length == kPageSize,
      );
    });
  }

  /// All listings of one farmer, newest first (for My Crops and the
  /// farmer's profile). One farmer has few listings, so we load them all.
  Future<List<Listing>> fetchByFarmer(String farmerId) {
    return runSafely('load farmer listings', () async {
      final snapshot = await _listings
          .where('farmerId', isEqualTo: farmerId)
          .get();
      final listings = snapshot.docs
          .map((doc) => Listing.fromMap(doc.id, doc.data()))
          .toList();
      // Sorting here instead of in Firestore means we need no extra index.
      listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return listings;
    });
  }

  /// Live version of [fetchByFarmer], so My Crops shows stock changes from
  /// Orders right away.
  Stream<List<Listing>> watchByFarmer(String farmerId) {
    return _listings.where('farmerId', isEqualTo: farmerId).snapshots().map((
      snapshot,
    ) {
      final listings = snapshot.docs
          .map((doc) => Listing.fromMap(doc.id, doc.data()))
          .toList();
      listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return listings;
    });
  }

  /// Loads one listing, or null if it was deleted.
  Future<Listing?> fetchById(String id) {
    return runSafely('load listing', () async {
      final doc = await _listings.doc(id).get();
      if (!doc.exists) return null;
      return Listing.fromMap(doc.id, doc.data()!);
    });
  }

  /// Live copy of one listing (null once deleted), so the listing page
  /// shows the available amount change as soon as stock is held or sold.
  Stream<Listing?> watch(String id) {
    return _listings
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Listing.fromMap(doc.id, doc.data()!) : null);
  }

  /// Adds a new listing (when id is empty) or updates an existing one, and
  /// returns its id. [newPhoto] saves the farmer's (already shrunk) photo;
  /// [removePhoto] deletes it. The listing and its photo are written in one
  /// batch, so we never end up with a listing that points to no photo.
  Future<String> save(
    Listing listing, {
    Uint8List? newPhoto,
    bool removePhoto = false,
  }) {
    return runSafely('save listing', () async {
      final isNew = listing.id.isEmpty;
      final ref = isNew ? _listings.doc() : _listings.doc(listing.id);
      final hasPhoto = newPhoto != null || (listing.hasPhoto && !removePhoto);
      final data = {...listing.toMap(), 'hasPhoto': hasPhoto};
      final photoRef = ListingPhotoService.collection.doc(ref.id);

      final batch = FirebaseFirestore.instance.batch();
      if (isNew) {
        batch.set(ref, {...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        batch.update(ref, data);
      }
      if (newPhoto != null) {
        batch.set(
          photoRef,
          ListingPhotoService.toMap(listing.farmerId, newPhoto),
        );
      } else if (removePhoto && listing.hasPhoto) {
        batch.delete(photoRef);
      }
      await batch.commit();
      if (newPhoto != null || removePhoto) {
        ListingPhotoService.instance.remember(
          ref.id,
          hasPhoto ? newPhoto : null,
        );
      }
      return ref.id;
    });
  }

  /// The newest [limit] listings that are for sale, with optional crop
  /// and town filters (null = all). The Market searches, filters, sorts
  /// and splits these into pages on the phone, so all of those work
  /// together. Sold out and removed listings are left out.
  Future<List<Listing>> fetchForMarket({
    String? crop,
    String? town,
    int limit = 100,
  }) {
    return runSafely('load marketplace', () async {
      Query<Map<String, dynamic>> query = _listings;
      if (crop != null) query = query.where('crop', isEqualTo: crop);
      if (town != null) query = query.where('town', isEqualTo: town);
      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => Listing.fromMap(doc.id, doc.data()))
          // Only crops buyers can still ask for. A fully reserved crop
          // comes back by itself when a hold is cancelled or runs out.
          .where((listing) => listing.isActive && listing.available > 0)
          .toList();
    });
  }

  /// Live version of [fetchForMarket]: one query whose results update by
  /// themselves when a farmer's stock changes (Firestore only sends the
  /// listings that changed, so this stays cheap).
  Stream<List<Listing>> watchForMarket({
    String? crop,
    String? town,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _listings;
    if (crop != null) query = query.where('crop', isEqualTo: crop);
    if (town != null) query = query.where('town', isEqualTo: town);
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Listing.fromMap(doc.id, doc.data()))
              .where((listing) => listing.isActive && listing.available > 0)
              .toList(),
        );
  }

  /// Changes only a listing's status, e.g. to sold out.
  Future<void> setStatus(String id, String status) {
    return runSafely(
      'change listing status',
      () => _listings.doc(id).update({'status': status}),
    );
  }

  /// Deletes a listing for good, together with its photo.
  Future<void> delete(Listing listing) {
    return runSafely('delete listing', () {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(_listings.doc(listing.id));
      if (listing.hasPhoto) {
        batch.delete(ListingPhotoService.collection.doc(listing.id));
      }
      return batch.commit();
    });
  }

  /// Puts a deleted listing back exactly as it was (for the Undo button).
  /// [photo] is its photo from before (null = no photo any more).
  Future<void> restore(Listing listing, {Uint8List? photo}) {
    return runSafely('restore listing', () {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_listings.doc(listing.id), {
        ...listing.toMap(),
        'hasPhoto': photo != null,
        'soldQty': listing.soldQty,
        'reservations': [for (final r in listing.reservations) r.toMap()],
        'createdAt': Timestamp.fromDate(listing.createdAt),
      });
      if (photo != null) {
        batch.set(
          ListingPhotoService.collection.doc(listing.id),
          ListingPhotoService.toMap(listing.farmerId, photo),
        );
      }
      return batch.commit();
    });
  }
}
