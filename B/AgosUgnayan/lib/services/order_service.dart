// Orders between buyers and farmers (orders collection), and the stock they
// hold on listings. Every change to a listing's stock runs in a Firestore
// transaction: the farmer's app reads the listing again and refuses when
// there is not enough left, so two buyers can never get the same kilos.
// Only the farmer's app ever writes stock (the rules allow nothing else).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/listing.dart';
import '../models/order.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';
import '../utils/format.dart';
import 'message_service.dart';

/// Making, answering and finishing orders.
class OrderService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  DocumentReference<Map<String, dynamic>> _listing(String id) =>
      _db.collection('listings').doc(id);

  // ---------------------------------------------------------------- reading

  /// Live list of all my orders (as buyer or farmer), newest first. One
  /// query for the whole Orders screen keeps reads low.
  Stream<List<CropOrder>> watchMine(String myId, {int limit = 200}) {
    return _orders
        .where('participants', arrayContains: myId)
        .limit(limit)
        .snapshots()
        .map(_sortedOrders);
  }

  /// Live orders of one chat, for the order cards inside the conversation.
  Stream<List<CropOrder>> watchChat(String chatId, String myId) {
    return _orders
        .where('participants', arrayContains: myId)
        .where('chatId', isEqualTo: chatId)
        .snapshots()
        .map(_sortedOrders);
  }

  List<CropOrder> _sortedOrders(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final orders = snapshot.docs
        .map((doc) => CropOrder.fromMap(doc.id, doc.data()))
        .toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  // ----------------------------------------------------------------- buyer

  /// The buyer's "Request to buy" on a listing. Creates a pending order and
  /// an order card in the chat with the farmer. Stock does NOT change: it is
  /// only held when the farmer accepts.
  Future<void> requestToBuy({
    required Listing listing,
    required double qty,
    required String note,
    required String buyerId,
    required String buyerName,
  }) {
    return runSafely('send request', () async {
      final chatId = await MessageService().openChat(
        myId: buyerId,
        myName: buyerName,
        otherId: listing.farmerId,
        otherName: listing.farmerName,
      );
      final order = CropOrder(
        id: '',
        source: OrderSource.listing,
        listingId: listing.id,
        farmerId: listing.farmerId,
        farmerName: listing.farmerName,
        buyerId: buyerId,
        buyerName: buyerName,
        chatId: chatId,
        crop: listing.crop,
        title: listing.title,
        unit: listing.unit,
        qty: qty,
        price: listing.price,
        note: note,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      );
      final ref = _orders.doc();
      final batch = _db.batch();
      batch.set(ref, _newOrderMap(order));
      _addOrderMessage(batch, order, ref.id, buyerId, 'Request to buy');
      await batch.commit();
    });
  }

  // ---------------------------------------------------------------- farmer

  /// The farmer's offer in a chat. With [fromListing], the stock is held on
  /// that listing right away (only the farmer may write a listing, and the
  /// buyer's app will accept it later), so the same kilos are never
  /// offered twice. Without it, it is a private offer: only the order
  /// tracks it, and it never appears in the Market.
  Future<void> sendOffer({
    required String chatId,
    required String farmerId,
    required String farmerName,
    required String buyerId,
    required String buyerName,
    required String crop,
    required String unit,
    required double qty,
    required double price,
    required String note,
    Listing? fromListing,
  }) {
    return runSafely('send offer', () async {
      final ref = _orders.doc();
      final now = DateTime.now();
      // A held offer waits 3 days for the buyer, then keeps the stock 3
      // more days for pickup. The farmer can extend it later.
      final holdUntil = now.add(kOrderWaitTime + kHoldTime);
      final order = CropOrder(
        id: ref.id,
        source: OrderSource.offer,
        listingId: fromListing?.id ?? '',
        farmerId: farmerId,
        farmerName: farmerName,
        buyerId: buyerId,
        buyerName: buyerName,
        chatId: chatId,
        crop: crop,
        title: fromListing?.title ?? '',
        unit: unit,
        qty: qty,
        price: price,
        note: note,
        status: OrderStatus.offered,
        createdAt: now,
        reservedUntil: fromListing == null ? null : holdUntil,
      );
      await _transaction((tx) async {
        if (fromListing != null) {
          final listing = await _read(tx, fromListing.id);
          _checkEnough(listing, qty, now);
          _writeReservations(tx, listing, [
            ...listing.reservations,
            Reservation(orderId: ref.id, qty: qty, until: holdUntil),
          ]);
        }
        tx.set(ref, _newOrderMap(order));
        _addOrderMessage(tx, order, ref.id, farmerId, 'Offer');
      });
    });
  }

  /// Accept. The farmer accepting a buyer's request holds the stock on the
  /// listing (refused if there is not enough left). The buyer accepting an
  /// offer only changes the order: any listing stock is already held.
  Future<void> accept(CropOrder order, {required bool byFarmer}) {
    return runSafely('accept order', () async {
      final ref = _orders.doc(order.id);
      if (!byFarmer) {
        await ref.update(_statusChange(OrderStatus.reserved));
      } else {
        final until = DateTime.now().add(kHoldTime);
        await _transaction((tx) async {
          if (order.usesListing) {
            final listing = await _read(tx, order.listingId);
            _checkEnough(listing, order.qty, DateTime.now());
            _writeReservations(tx, listing, [
              ..._without(listing, order.id),
              Reservation(orderId: order.id, qty: order.qty, until: until),
            ]);
          }
          tx.update(ref, {
            ..._statusChange(OrderStatus.reserved),
            'reservedUntil': until,
          });
        });
      }
      _tellOtherSide(
        order,
        fromId: byFarmer ? order.farmerId : order.buyerId,
        text: byFarmer
            ? 'Accepted: ${_amount(order)} is held for you until '
                  '${formatDate(DateTime.now().add(kHoldTime))}.'
            : 'Accepted your offer of ${_amount(order)}.',
      );
    });
  }

  /// Decline a request (farmer) or an offer (buyer). No stock changes for a
  /// request; a held offer's stock is freed by the farmer's app later
  /// (see [releaseClosedHolds]).
  Future<void> decline(CropOrder order, {required bool byFarmer}) {
    return runSafely('decline order', () async {
      await _orders.doc(order.id).update(_statusChange(OrderStatus.declined));
      _tellOtherSide(
        order,
        fromId: byFarmer ? order.farmerId : order.buyerId,
        text: 'Declined: ${_amount(order)}.',
      );
    });
  }

  /// Cancel. A buyer can cancel only a request that is still pending. The
  /// farmer can cancel an offer or a reservation; its stock is freed.
  Future<void> cancel(CropOrder order, {required bool byFarmer}) {
    return runSafely('cancel order', () async {
      final ref = _orders.doc(order.id);
      if (!byFarmer) {
        await ref.update(_statusChange(OrderStatus.cancelled));
      } else {
        await _transaction((tx) async {
          if (order.usesListing) {
            final listing = await _read(tx, order.listingId);
            final kept = _without(listing, order.id);
            if (kept.length != listing.reservations.length) {
              _writeReservations(tx, listing, kept);
            }
          }
          tx.update(ref, _statusChange(OrderStatus.cancelled));
        });
      }
      _tellOtherSide(
        order,
        fromId: byFarmer ? order.farmerId : order.buyerId,
        text: 'Cancelled: ${_amount(order)}.',
      );
    });
  }

  /// The farmer marks a reserved order as sold: its hold becomes sold
  /// stock. When nothing is left and nothing is held, the listing becomes
  /// Sold out by itself.
  Future<void> markSold(CropOrder order) {
    return runSafely('mark sold', () async {
      await _transaction((tx) async {
        if (order.usesListing) {
          final now = DateTime.now();
          final listing = await _read(tx, order.listingId);
          final hold = listing.reservationFor(order.id);
          // If the hold already ran out, the kilos must still be free.
          if (hold == null || !hold.isActiveAt(now)) {
            _checkEnough(listing, order.qty, now);
          }
          final kept = _without(listing, order.id);
          final sold = listing.soldQty + order.qty;
          final leftAfter = listing.quantity - sold;
          final stillHeld = kept.any((r) => r.isActiveAt(now));
          tx.update(_listing(listing.id), {
            'soldQty': sold,
            'reservations': [for (final r in kept) r.toMap()],
            if (leftAfter <= 0 && !stillHeld) 'status': ListingStatus.sold,
          });
        }
        tx.update(_orders.doc(order.id), _statusChange(OrderStatus.completed));
      });
      _tellOtherSide(
        order,
        fromId: order.farmerId,
        text: 'Sold: ${_amount(order)}. Thank you!',
      );
    });
  }

  /// The farmer keeps the stock 3 more days (from now, or from the current
  /// end date if that is later).
  Future<void> extendHold(CropOrder order) {
    return runSafely('extend hold', () async {
      final now = DateTime.now();
      final current = order.reservedUntil ?? now;
      final until = (current.isAfter(now) ? current : now).add(kHoldTime);
      await _transaction((tx) async {
        if (order.usesListing) {
          final listing = await _read(tx, order.listingId);
          final hold = listing.reservationFor(order.id);
          if (hold == null || !hold.isActiveAt(now)) {
            _checkEnough(listing, order.qty, now);
          }
          _writeReservations(tx, listing, [
            ..._without(listing, order.id),
            Reservation(orderId: order.id, qty: order.qty, until: until),
          ]);
        }
        tx.update(_orders.doc(order.id), {
          ..._statusChange(OrderStatus.reserved),
          'reservedUntil': until,
        });
      });
    });
  }

  /// Frees stock still held for offers the buyer declined or never
  /// answered (the buyer's app may not write the farmer's listing). Called
  /// by the farmer's Orders screen; writes only when something is held.
  Future<void> releaseClosedHolds(List<CropOrder> orders) async {
    final now = DateTime.now();
    final closed = orders.where(
      (o) =>
          o.isPrivateOffer &&
          o.usesListing &&
          (o.stateAt(now) == OrderState.declined ||
              o.stateAt(now) == OrderState.expired),
    );
    for (final order in closed) {
      if (_released.contains(order.id)) continue;
      _released.add(order.id);
      try {
        await _transaction((tx) async {
          final listing = await _read(tx, order.listingId);
          final kept = _without(listing, order.id);
          if (kept.length != listing.reservations.length) {
            _writeReservations(tx, listing, kept);
          }
        });
      } catch (e) {
        AppLogger.error('release hold failed', e); // tried again next time
        _released.remove(order.id);
      }
    }
  }

  /// Orders already checked by [releaseClosedHolds] while the app is open.
  static final Set<String> _released = {};

  // --------------------------------------------------------------- helpers

  /// Runs [body] as a Firestore transaction. When it refuses (an
  /// [AppException], e.g. "Only 3 kg is left"), that friendly message
  /// reaches the screen: on the web, Firestore would otherwise replace it
  /// with a generic error when it crosses into JavaScript.
  Future<void> _transaction(Future<void> Function(Transaction tx) body) async {
    String? refusal;
    try {
      await _db.runTransaction((tx) async {
        try {
          await body(tx);
        } on AppException catch (e) {
          refusal = e.message;
          rethrow;
        }
      });
    } catch (e) {
      final message = refusal;
      if (message != null) throw AppException(message);
      rethrow;
    }
  }

  Future<Listing> _read(Transaction tx, String listingId) async {
    final doc = await tx.get(_listing(listingId));
    if (!doc.exists) {
      throw const AppException('This crop listing was deleted.');
    }
    return Listing.fromMap(doc.id, doc.data()!);
  }

  /// Throws a friendly message when [listing] has less than [qty] free.
  static void _checkEnough(Listing listing, double qty, DateTime now) {
    if (listing.status == ListingStatus.removed) {
      throw const AppException('This crop is removed from the Market.');
    }
    if (listing.status == ListingStatus.sold) {
      throw const AppException('This crop is marked as sold out.');
    }
    final left = listing.availableAt(now);
    if (qty > left + 0.0001) {
      throw AppException(
        left <= 0
            ? 'Nothing is left of this crop to hold.'
            : 'Only ${formatQuantity(left)} ${listing.unit} is left. '
                  'Ask the buyer to take less, or decline.',
      );
    }
  }

  static List<Reservation> _without(Listing listing, String orderId) =>
      listing.reservations.where((r) => r.orderId != orderId).toList();

  void _writeReservations(
    Transaction tx,
    Listing listing,
    List<Reservation> reservations,
  ) {
    tx.update(_listing(listing.id), {
      'reservations': [for (final r in reservations) r.toMap()],
    });
  }

  static Map<String, dynamic> _statusChange(String status) => {
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, dynamic> _newOrderMap(CropOrder order) => {
    ...order.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _amount(CropOrder order) =>
      '${formatQuantity(order.qty)} ${order.unit} of ${order.crop}';

  /// Adds the order card message to the chat in the same batch or
  /// transaction as the order, and updates the inbox preview.
  void _addOrderMessage(
    dynamic writer, // a WriteBatch or a Transaction: both have set/update
    CropOrder order,
    String orderId,
    String senderId,
    String kind,
  ) {
    final chat = _db.collection('chats').doc(order.chatId);
    final text =
        '$kind: ${_amount(order)} at ${formatPeso(order.price)}/${order.unit}'
        ' (${formatPeso(order.total)})';
    writer.set(chat.collection('messages').doc(), {
      'senderId': senderId,
      'text': text,
      'type': 'order',
      'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    writer.update(chat, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'readAt.$senderId': FieldValue.serverTimestamp(),
    });
  }

  /// A short chat message so the other person sees the change (and gets
  /// the unread dot). Failing here does not undo the order change.
  void _tellOtherSide(
    CropOrder order, {
    required String fromId,
    required String text,
  }) {
    if (order.chatId.isEmpty) return;
    MessageService()
        .send(chatId: order.chatId, senderId: fromId, text: text)
        .catchError((Object e) => AppLogger.error('order message failed', e));
  }
}
