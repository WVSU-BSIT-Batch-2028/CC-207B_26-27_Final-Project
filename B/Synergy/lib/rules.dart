import 'dart:math';

import 'models.dart';

// The four tags founders can pick. Use these exact spellings.
const allTags = [
  'Beta Testers',
  'Product Feedback',
  'User Research',
  'Technical Development',
];

// Exchanges at these stages show as rooms
const roomStages = ['accepted', 'termsAgreed', 'launched', 'reviewed'];

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

  // True if id is the sender or the recipient
  static bool isParticipant(Exchange e, String id) =>
      e.senderId == id || e.recipientId == id;

  // Goal and deliverables filled in, at least one tester
  static bool validTerms(String goal, int testerCount, String deliverables) =>
      goal.trim().isNotEmpty &&
      deliverables.trim().isNotEmpty &&
      testerCount > 0;

  // Either startup can edit the terms until both have agreed
  static bool canEditTerms(Exchange e, String actorId) =>
      isParticipant(e, actorId) && e.stage == 'accepted';

  // Someone has proposed terms
  static bool hasTerms(Exchange e) => e.goal.isNotEmpty;

  // A startup in the room that hasn't agreed to the current terms yet
  static bool canAgreeTerms(Exchange e, String actorId) =>
      isParticipant(e, actorId) &&
      e.stage == 'accepted' &&
      hasTerms(e) &&
      !e.termsAgreedBy.contains(actorId);

  // Both startups agreed, so the terms are final
  static bool termsLocked(Exchange e) =>
      e.termsAgreedBy.contains(e.senderId) &&
      e.termsAgreedBy.contains(e.recipientId);

  // Simulated partner's next step, or null if nothing to do.
  // 'accept' or 'agreeTerms' for now, later milestones add more.
  static String? nextPartnerAction(Exchange e, String partnerId) {
    if (canAccept(e, partnerId)) return 'accept';
    if (canAgreeTerms(e, partnerId)) return 'agreeTerms';
    return null;
  }

  // 0–100: how well a and b cover each other's needs.
  // The weaker direction sets the score. No needs = 0.
  static int matchFit(Startup a, Startup b) {
    final aNeeds = a.needs.toSet();
    final bNeeds = b.needs.toSet();
    if (aNeeds.isEmpty || bNeeds.isEmpty) return 0;
    final share1 = theyOffer(a, b).length / aNeeds.length;
    final share2 = youOffer(a, b).length / bNeeds.length;
    return (100 * min(share1, share2)).round();
  }

  // Tags B offers that A needs
  static List<String> theyOffer(Startup a, Startup b) =>
      a.needs.toSet().where(b.offers.contains).toList();

  // Tags A offers that B needs
  static List<String> youOffer(Startup a, Startup b) =>
      b.needs.toSet().where(a.offers.contains).toList();

  // Tags B needs that A does not offer
  static List<String> theyStillNeed(Startup a, Startup b) =>
      b.needs.toSet().where((t) => !a.offers.contains(t)).toList();

  // True if the exchange links a and b, in either direction
  static bool _isBetween(Exchange e, String a, String b) =>
      (e.senderId == a && e.recipientId == b) ||
      (e.senderId == b && e.recipientId == a);
}
