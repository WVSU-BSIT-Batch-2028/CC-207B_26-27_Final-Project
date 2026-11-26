// One deal between one buyer and one farmer, saved at orders/{id}. It
// starts either from a Market listing (the buyer asks) or from a private
// offer in the chat (the farmer offers). See docs/inventory-design.md.

import 'firestore_date.dart';

/// How long a request or offer waits for an answer, and how long accepted
/// stock is held for the buyer.
const Duration kOrderWaitTime = Duration(days: 3);
const Duration kHoldTime = Duration(days: 3);

/// The status saved in Firestore.
class OrderStatus {
  OrderStatus._();

  static const String pending = 'pending'; // buyer asked, farmer must answer
  static const String offered = 'offered'; // farmer offered, buyer must answer
  static const String reserved = 'reserved'; // accepted: stock is held
  static const String completed = 'completed'; // sold
  static const String declined = 'declined';
  static const String cancelled = 'cancelled';
}

/// What the order means right now, including "expired", which is worked
/// out from the dates and never saved (we have no server to change it).
enum OrderState {
  pending, // waiting for the farmer
  offered, // waiting for the buyer
  reserved, // stock held for the buyer
  holdEnded, // was reserved, but the hold date passed: stock is free again
  completed,
  declined,
  cancelled,
  expired, // a request or offer nobody answered in time
}

/// Where an order came from.
class OrderSource {
  OrderSource._();

  static const String listing = 'listing'; // "Request to buy" on a listing
  static const String offer = 'offer'; // farmer's offer in the chat
}

/// One order: who, what, how much, and where it stands.
class CropOrder {
  const CropOrder({
    required this.id,
    required this.source,
    required this.listingId,
    required this.farmerId,
    required this.farmerName,
    required this.buyerId,
    required this.buyerName,
    required this.chatId,
    required this.crop,
    required this.title,
    required this.unit,
    required this.qty,
    required this.price,
    required this.note,
    required this.status,
    required this.createdAt,
    this.reservedUntil,
  });

  final String id;
  final String source; // one of OrderSource
  final String listingId; // empty for a private offer with no listing
  final String farmerId;
  final String farmerName;
  final String buyerId;
  final String buyerName;
  final String chatId;
  final String crop;
  final String title; // the listing's title, if it had one
  final String unit;
  final double qty;
  final double price; // per unit
  final String note;
  final String status; // one of OrderStatus
  final DateTime createdAt;
  final DateTime? reservedUntil; // when the hold ends

  /// Quantity × price, rounded to centavos.
  double get total => orderTotal(qty, price);

  bool get isPrivateOffer => source == OrderSource.offer;

  /// True when the stock comes from (and is counted on) a listing.
  bool get usesListing => listingId.isNotEmpty;

  /// The order's meaning at [now], with expiry worked out from the dates.
  OrderState stateAt(DateTime now) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.offered:
        if (!createdAt.add(kOrderWaitTime).isAfter(now)) {
          return OrderState.expired;
        }
        return status == OrderStatus.pending
            ? OrderState.pending
            : OrderState.offered;
      case OrderStatus.reserved:
        final until = reservedUntil;
        if (until != null && !until.isAfter(now)) return OrderState.holdEnded;
        return OrderState.reserved;
      case OrderStatus.completed:
        return OrderState.completed;
      case OrderStatus.declined:
        return OrderState.declined;
      default:
        return OrderState.cancelled;
    }
  }

  OrderState get state => stateAt(DateTime.now());

  /// When a waiting request or offer runs out.
  DateTime get answerBy => createdAt.add(kOrderWaitTime);

  factory CropOrder.fromMap(String id, Map<String, dynamic> data) {
    return CropOrder(
      id: id,
      source: data['source'] as String? ?? OrderSource.listing,
      listingId: data['listingId'] as String? ?? '',
      farmerId: data['farmerId'] as String? ?? '',
      farmerName: data['farmerName'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? '',
      chatId: data['chatId'] as String? ?? '',
      crop: data['crop'] as String? ?? '',
      title: data['title'] as String? ?? '',
      unit: data['unit'] as String? ?? 'kg',
      qty: readDouble(data['qty']),
      price: readDouble(data['price']),
      note: data['note'] as String? ?? '',
      status: data['status'] as String? ?? OrderStatus.pending,
      createdAt: readDate(data['createdAt']),
      reservedUntil: readOptionalDate(data['reservedUntil']),
    );
  }

  /// The fields saved when the order is made. The rules check that
  /// `total` really is qty × price.
  Map<String, dynamic> toMap() => {
    'source': source,
    'listingId': listingId,
    'farmerId': farmerId,
    'farmerName': farmerName,
    'buyerId': buyerId,
    'buyerName': buyerName,
    // For the security rules and the "my orders" query: both people.
    'participants': [buyerId, farmerId],
    'chatId': chatId,
    'crop': crop,
    'title': title,
    'unit': unit,
    'qty': qty,
    'price': price,
    'total': total,
    'note': note,
    'status': status,
    'reservedUntil': reservedUntil,
  };
}

/// [qty] × [price] rounded to centavos (so ₱54.40 × 5 is exactly ₱272.00).
double orderTotal(double qty, double price) =>
    (qty * price * 100).round() / 100;
