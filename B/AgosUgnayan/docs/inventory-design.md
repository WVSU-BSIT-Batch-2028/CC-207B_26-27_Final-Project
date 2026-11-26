# Inventory, orders and private offers: design note

This note explains how listing titles, farmer photos, stock (available / reserved / sold) and chat offers work, and why. We are on Firebase's free Spark plan: there are no Cloud Functions (no server code) and no Firebase Storage. So everything runs in the app, protected by Firestore transactions and security rules, and anything that depends on time is worked out from dates (like expired buyer requests).

## Data model

### `listings/{id}` (existing, new fields)

| Field | Meaning |
|---|---|
| `title` | Optional listing title or stall name, e.g. "Juan's Food Stall" (max 40 characters). The crop stays in `crop`, so search, filters and categories keep using the real crop. |
| `hasPhoto` | `true` when the farmer uploaded a photo (stored in `listing_photos/{id}`). |
| `quantity` | **Total stock** the farmer posted (old listings keep working). |
| `soldQty` | How much was sold through orders. Missing = 0. |
| `reservations` | List of `{orderId, qty, until}`: stock held for one buyer until a date. |

Nothing else is stored. Every screen uses one helper (`StockMath` in `lib/models/stock.dart`):

- reserved now = sum of `qty` of reservations whose `until` is still in the future
- available = `quantity` − `soldQty` − reserved now

So a reservation that runs out simply stops counting, for every viewer, with no write and no server. Only the farmer (the listing owner) ever writes `soldQty` and `reservations`, always inside a Firestore transaction. That way two buyers can never be given more than exists: the farmer's app reads the listing again inside the transaction and refuses if there is not enough left.

### `listing_photos/{listingId}` (new)

`{farmerId, data (JPEG as base64), updatedAt}`. The app shrinks the photo first: at most 800 px on the longest side, JPEG quality 70 (lower if needed), aiming at 150 KB and refusing anything that still exceeds 300 KB. The photo lives in its own document so loading the Market list doesn't download every photo. Cards load photos one by one and keep them in memory.

### `orders/{id}` (new)

One deal between one buyer and one farmer.

| Field | Meaning |
|---|---|
| `source` | `listing` (buyer asked from a Market listing) or `offer` (farmer offered in chat) |
| `listingId` | The listing the stock comes from, or empty for a private offer with no listing |
| `farmerId`, `farmerName`, `buyerId`, `buyerName`, `chatId` | Who and where (names copied when the order is made) |
| `crop`, `title`, `unit`, `qty`, `price`, `total` | What, how much, price per unit and the total |
| `note` | Optional message |
| `status` | `pending` (buyer asked), `offered` (farmer offered), `reserved`, `completed`, `declined`, `cancelled` |
| `createdAt`, `updatedAt`, `reservedUntil` | Dates |

**Expired** is never saved: a `pending` or `offered` order expires 3 days after it was made, and a `reserved` order's hold ends at `reservedUntil` (3 days after it was accepted; the farmer can extend it by 3 days). An expired order is treated as closed and its stock as free again.

### `chats/{id}/messages/{id}` (existing, one new kind)

A message can have `type: 'order'` and `orderId`. The chat shows it as an order card that reads the live order, so its status is always current. Old text messages keep working.

## Flows

1. **Buyer from a listing.** The listing page shows "Available: 15 kg". "Request to buy" asks for a quantity (more than 0, at most the available amount) and an optional note, and shows the total. It creates an order with status `pending` and posts an order card in the chat with that farmer. **Stock does not change.** A normal chat message never changes stock either.
2. **Farmer answers.** On the Orders screen or the chat card, the farmer can:
   - **Accept**: in a transaction, the app reads the listing again, refuses with "Only 3 kg left" if there is not enough, adds the reservation, and sets the order to `reserved`.
   - **Decline**: asks first.
   - **Mark as sold**: in a transaction, removes the reservation, adds to `soldQty` and sets the order to `completed`. When nothing is available and nothing is reserved, the listing becomes Sold out.
   - **Cancel**: asks first. The reservation is removed, so the stock is free again.
   - **Extend 3 days**.
3. **Buyer.** Can cancel a pending request. For a reserved order the buyer cannot touch the farmer's stock, so "Ask to cancel" sends a chat message instead.
4. **Private offer in chat.** The farmer taps "Send an offer" and fills in crop, quantity, price and an optional note; the app works out the total.
   - **Optional "Take from my listing".** If picked, the stock is held on that listing at once, so the same kilos are never counted twice. The buyer's app is not allowed to write the farmer's listing, so the hold has to be made by the farmer when sending the offer.
   - **No listing picked.** It is a private offer: only the order tracks it.
   - **Buyer's answer.** The buyer accepts (`reserved`) or declines.
   - **Never public.** A private offer is never shown in the Market or to anyone else.
5. **Market.** Listings stream live. Cards show the available amount, "Only 3 kg left" when low, and "Fully reserved" or "Sold out" when nothing is available; then the Request button is turned off with the reason.

## Security rules (summary)

- `listings`: only the owner writes (so only the farmer changes `soldQty` and `reservations`).
- `listing_photos`: anyone signed in reads. Only the listing's owner writes, and the photo text must be under 450 KB.
- `orders`: only the buyer and the farmer of the order can read it.
  - **Creating.** A buyer can create only a `pending` listing order for themselves. A farmer can create only an `offered` order for themselves. The quantity must be above 0, and the total must match quantity × price.
  - **Changing.** Updates may change only `status`, `updatedAt` and `reservedUntil`, so nobody edits the other person's fields.
  - **Allowed status changes.** The buyer may go pending → cancelled and offered → reserved/declined. The farmer may go pending → reserved/declined, reserved → completed/cancelled, and offered → cancelled.

## Limits

- No push notifications: changes show in the app (chat cards, Orders counts).
- Holds end by date only. A late hold stops counting by itself, but the order shows "Reservation ended" until the farmer marks it sold, extends it or cancels it.
- Photos are small (800 px), because they are stored in Firestore instead of Storage.
