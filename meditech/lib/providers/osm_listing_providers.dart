import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/osm_listing.dart';
import '../services/osm_listing_service.dart';

final osmListingServiceProvider = Provider<OsmListingService>((ref) {
  return OsmListingService();
});

final shownOsmListingsProvider = FutureProvider<List<OsmListing>>((ref) async {
  return ref.watch(osmListingServiceProvider).fetchShownListings();
});

final osmListingDetailProvider = FutureProvider.family<OsmListing?, String>((
  ref,
  id,
) async {
  return ref.watch(osmListingServiceProvider).fetchListingById(id);
});

final nearbyOsmListingsProvider =
    FutureProvider.family<List<OsmListing>, ({double lat, double lng})>((
      ref,
      coords,
    ) async {
      return ref
          .watch(osmListingServiceProvider)
          .findNearbyListings(
            latitude: coords.lat,
            longitude: coords.lng,
            radiusMeters: 100,
          );
    });

class AdminOsmListingsNotifier extends AsyncNotifier<List<OsmListing>> {
  @override
  Future<List<OsmListing>> build() {
    return ref.watch(osmListingServiceProvider).fetchAllForAdmin();
  }

  Future<void> hideListing({
    required String listingId,
    required String reason,
  }) async {
    await ref
        .read(osmListingServiceProvider)
        .hideListing(listingId: listingId, reason: reason);
    ref.invalidateSelf();
    await future;
  }

  Future<void> showListingAgain({required String listingId}) async {
    await ref
        .read(osmListingServiceProvider)
        .showListingAgain(listingId: listingId);
    ref.invalidateSelf();
    await future;
  }

  Future<int> syncFromOpenStreetMap() async {
    final count = await ref
        .read(osmListingServiceProvider)
        .syncFromOpenStreetMap();
    ref.invalidateSelf();
    await future;
    return count;
  }
}

final adminOsmListingsProvider =
    AsyncNotifierProvider<AdminOsmListingsNotifier, List<OsmListing>>(
      AdminOsmListingsNotifier.new,
    );
