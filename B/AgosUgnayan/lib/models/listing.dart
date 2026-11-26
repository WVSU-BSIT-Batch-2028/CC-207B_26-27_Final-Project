// A crop listing posted by a farmer, saved in Firestore at listings/{id}.

import 'firestore_date.dart';

/// Where a listing is: for sale, sold out, or removed by the farmer.
/// Listings saved before this field existed count as active.
class ListingStatus {
  ListingStatus._();

  static const String active = 'active'; // buyers see it in the Market
  static const String sold = 'sold'; // sold out, kept for the farmer
  static const String removed = 'removed'; // hidden, can be put back
}

/// Stock held for one buyer's order until [until]. After that date it
/// stops counting by itself, so nothing has to be "released" by a server.
class Reservation {
  const Reservation({
    required this.orderId,
    required this.qty,
    required this.until,
  });

  final String orderId;
  final double qty;
  final DateTime until;

  /// True while the hold still counts.
  bool isActiveAt(DateTime now) => until.isAfter(now);

  factory Reservation.fromMap(Map<String, dynamic> data) => Reservation(
    orderId: data['orderId'] as String? ?? '',
    qty: readDouble(data['qty']),
    until: readDate(data['until']),
  );

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'qty': qty,
    'until': until,
  };
}

/// What buyers can do with a listing right now.
enum StockState {
  available, // some left: buyers can ask for it
  fullyReserved, // nothing free, but holds may still come back
  soldOut, // everything sold
}

/// One crop a farmer is selling, e.g. "Tomato, 50 kg at ₱45.00/kg".
class Listing {
  const Listing({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.crop,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.town,
    required this.harvestDate,
    required this.description,
    required this.aiAssisted,
    required this.createdAt,
    this.status = ListingStatus.active,
    this.title = '',
    this.hasPhoto = false,
    this.soldQty = 0,
    this.reservations = const [],
  });

  final String id; // empty for a new listing that is not saved yet
  final String farmerId;
  final String farmerName;
  final String crop; // one of kCrops
  final double quantity; // the total stock the farmer posted
  final String unit; // one of kUnits
  final double price; // asking price per unit, in pesos
  final String town;
  final DateTime? harvestDate; // optional
  final String description;
  final bool aiAssisted; // true if the AI assistant helped fill the form
  final DateTime createdAt;
  final String status; // one of ListingStatus

  /// Optional listing title or stall name, e.g. "Juan's Food Stall".
  /// The real crop always stays in [crop] for search and filters.
  final String title;

  /// True when the farmer uploaded a photo (in listing_photos/{id}).
  final bool hasPhoto;

  /// How much was sold through orders (0 for older listings).
  final double soldQty;

  /// Stock held for buyers' orders (only the farmer writes these).
  final List<Reservation> reservations;

  /// Stock held right now: reservations whose date has not passed.
  double reservedAt(DateTime now) => reservations
      .where((r) => r.isActiveAt(now))
      .fold(0.0, (sum, r) => sum + r.qty);

  /// What buyers can still ask for: total − sold − held. Never below 0.
  /// Worked out every time instead of saved, so it is always right.
  double availableAt(DateTime now) {
    final left = quantity - soldQty - reservedAt(now);
    return left < 0 ? 0 : left;
  }

  double get reserved => reservedAt(DateTime.now());
  double get available => availableAt(DateTime.now());

  /// Available, fully reserved or sold out (for labels and buttons).
  StockState stockAt(DateTime now) {
    if (availableAt(now) > 0) return StockState.available;
    return reservedAt(now) > 0 ? StockState.fullyReserved : StockState.soldOut;
  }

  /// The reservation of [orderId], or null.
  Reservation? reservationFor(String orderId) {
    for (final r in reservations) {
      if (r.orderId == orderId) return r;
    }
    return null;
  }

  /// The card's headline: the title if there is one, else the crop.
  String get headline => title.isEmpty ? crop : title;

  /// The id to load the farmer's own photo with, or null for none.
  String? get photoId => hasPhoto && id.isNotEmpty ? id : null;

  /// True when buyers can see it in the Market.
  bool get isActive => status == ListingStatus.active;

  /// Builds a listing from a Firestore document.
  factory Listing.fromMap(String id, Map<String, dynamic> data) {
    return Listing(
      id: id,
      farmerId: data['farmerId'] as String? ?? '',
      farmerName: data['farmerName'] as String? ?? '',
      crop: data['crop'] as String? ?? '',
      quantity: readDouble(data['quantity']),
      unit: data['unit'] as String? ?? 'kg',
      price: readDouble(data['price']),
      town: data['town'] as String? ?? '',
      harvestDate: readOptionalDate(data['harvestDate']),
      description: data['description'] as String? ?? '',
      aiAssisted: data['aiAssisted'] as bool? ?? false,
      createdAt: readDate(data['createdAt']),
      status: data['status'] as String? ?? ListingStatus.active,
      title: (data['title'] as String? ?? '').trim(),
      hasPhoto: data['hasPhoto'] as bool? ?? false,
      soldQty: readDouble(data['soldQty']),
      reservations: [
        for (final r in data['reservations'] as List? ?? const [])
          if (r is Map<String, dynamic>) Reservation.fromMap(r),
      ],
    );
  }

  /// The fields we save to Firestore. createdAt is set by the service.
  Map<String, dynamic> toMap() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'crop': crop,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'town': town,
      'harvestDate': harvestDate,
      'description': description,
      'aiAssisted': aiAssisted,
      'status': status,
      'title': title,
      'hasPhoto': hasPhoto,
    };
  }
}
