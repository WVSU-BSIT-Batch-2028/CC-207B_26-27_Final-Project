import 'models.dart';

// Who can do what. Pure Dart, no Flutter, easy to test.
class Rules {
  // Stages that close an exchange, so a new invite is allowed again
  static const _closedStages = ['declined', 'withdrawn'];

  // Not to yourself, and no open exchange between the two startups
  static bool canSendInvite(
    String fromId,
    String toId,
    List<Exchange> exchanges,
  ) {
    if (fromId == toId) return false;
    return !exchanges.any(
      (e) => _isBetween(e, fromId, toId) && !_closedStages.contains(e.stage),
    );
  }

  // Only the recipient, only while pending
  static bool canAccept(Exchange e, String actorId) =>
      e.stage == 'pending' && e.recipientId == actorId;

  static bool canDecline(Exchange e, String actorId) =>
      e.stage == 'pending' && e.recipientId == actorId;

  // Only the sender, only while pending
  static bool canWithdraw(Exchange e, String actorId) =>
      e.stage == 'pending' && e.senderId == actorId;

  // Simulated partner's next step, or null if nothing to do.
  // Only 'accept' for now, later milestones add more.
  static String? nextPartnerAction(Exchange e, String partnerId) {
    if (canAccept(e, partnerId)) return 'accept';
    return null;
  }

  // True if the exchange links a and b, in either direction
  static bool _isBetween(Exchange e, String a, String b) =>
      (e.senderId == a && e.recipientId == b) ||
      (e.senderId == b && e.recipientId == a);
}
