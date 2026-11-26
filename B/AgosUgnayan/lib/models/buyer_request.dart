// A crop request posted by a buyer ("I need 100 kg of tomatoes by Friday"),
// saved in Firestore at requests/{id}.

import 'firestore_date.dart';

/// One thing a buyer wants to buy.
/// Where a buyer request is.
enum RequestStatus {
  /// Farmers see it in Buyer Demand and can offer their crops.
  open,

  /// Its "needed by" day passed and the buyer did not close it. Kept (not
  /// deleted), so the buyer can pick a new date or close it.
  expired,

  /// The buyer closed it (found a farmer or no longer needs it).
  closed,
}

class BuyerRequest {
  const BuyerRequest({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.crop,
    required this.quantity,
    required this.unit,
    required this.targetPrice,
    required this.town,
    required this.neededBy,
    required this.notes,
    required this.createdAt,
    this.closedByBuyer = false,
  });

  final String id;
  final String buyerId;
  final String buyerName;
  final String crop;
  final double quantity;
  final String unit;
  final double? targetPrice; // optional: the price the buyer hopes to pay
  final String town;
  final DateTime neededBy;
  final String notes;
  final DateTime createdAt;

  /// True when the buyer closed it (e.g. they found a farmer).
  final bool closedByBuyer;

  /// Open, Expired or Closed, worked out from the data every time it is
  /// read (the free Firebase plan has no server to change it at midnight).
  /// [now] can be given in tests; the app uses the phone's clock.
  RequestStatus statusAt(DateTime now) {
    if (closedByBuyer) return RequestStatus.closed;
    return daysLeftAt(now) < 0 ? RequestStatus.expired : RequestStatus.open;
  }

  /// Days from today until the "needed by" day, comparing dates only:
  /// 0 = needed today (still open all day), 1 = tomorrow, -3 = 3 days ago.
  int daysLeftAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(neededBy.year, neededBy.month, neededBy.day);
    // Rounding handles days that are 23 or 25 hours long.
    return (day.difference(today).inHours / 24).round();
  }

  RequestStatus get status => statusAt(DateTime.now());
  int get daysLeft => daysLeftAt(DateTime.now());

  /// True when the "needed by" day has passed and the buyer did not close it.
  bool get isExpired => status == RequestStatus.expired;

  /// Not open any more: expired or closed. Farmers only see open requests.
  bool get isClosed => status != RequestStatus.open;

  /// True when it is open and needed within [days] days (today counts).
  bool expiresSoon({int days = 1}) =>
      status == RequestStatus.open && daysLeft <= days;

  /// Builds a request from a Firestore document.
  factory BuyerRequest.fromMap(String id, Map<String, dynamic> data) {
    final target = data['targetPrice'];
    return BuyerRequest(
      id: id,
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? '',
      crop: data['crop'] as String? ?? '',
      quantity: readDouble(data['quantity']),
      unit: data['unit'] as String? ?? 'kg',
      targetPrice: target == null ? null : readDouble(target),
      town: data['town'] as String? ?? '',
      neededBy: readDate(data['neededBy']),
      notes: data['notes'] as String? ?? '',
      createdAt: readDate(data['createdAt']),
      closedByBuyer: data['closed'] as bool? ?? false,
    );
  }

  /// The fields we save to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'buyerName': buyerName,
      'crop': crop,
      'quantity': quantity,
      'unit': unit,
      'targetPrice': targetPrice,
      'town': town,
      'neededBy': neededBy,
      'notes': notes,
      'closed': closedByBuyer,
    };
  }
}
