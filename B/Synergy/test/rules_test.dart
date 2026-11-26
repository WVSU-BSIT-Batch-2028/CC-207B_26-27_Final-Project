import 'package:flutter_test/flutter_test.dart';
import 'package:synergy_flutter/models.dart';
import 'package:synergy_flutter/rules.dart';

const bb = 'budgetbuddy';
const cg = 'campus-grocer';
const pp = 'printpal';

// BudgetBuddy invites Campus Grocer
Exchange invite({String stage = 'pending'}) => Exchange(
  id: 'x1',
  senderId: bb,
  recipientId: cg,
  note: 'Could your students test our signup?',
  stage: stage,
);

void main() {
  group('canSendInvite', () {
    test('allowed when there is no exchange yet', () {
      expect(Rules.canSendInvite(bb, cg, []), isTrue);
    });

    test('blocked when inviting yourself', () {
      expect(Rules.canSendInvite(bb, bb, []), isFalse);
    });

    test('blocked when inviting the same startup twice', () {
      expect(Rules.canSendInvite(bb, cg, [invite()]), isFalse);
    });

    test('blocked the other way round too', () {
      expect(Rules.canSendInvite(cg, bb, [invite()]), isFalse);
    });

    test('blocked once the invite is accepted', () {
      expect(Rules.canSendInvite(bb, cg, [invite(stage: 'accepted')]), isFalse);
    });

    test('allowed again after a decline or withdraw', () {
      expect(Rules.canSendInvite(bb, cg, [invite(stage: 'declined')]), isTrue);
      expect(Rules.canSendInvite(bb, cg, [invite(stage: 'withdrawn')]), isTrue);
    });

    test('an exchange with someone else does not block', () {
      expect(Rules.canSendInvite(bb, pp, [invite()]), isTrue);
    });
  });

  group('canAccept', () {
    test('the recipient can accept a pending invite', () {
      expect(Rules.canAccept(invite(), cg), isTrue);
    });

    test('the sender cannot accept their own invite', () {
      expect(Rules.canAccept(invite(), bb), isFalse);
    });

    test('an outsider cannot accept', () {
      expect(Rules.canAccept(invite(), pp), isFalse);
    });

    test('cannot accept something already declined', () {
      expect(Rules.canAccept(invite(stage: 'declined'), cg), isFalse);
    });

    test('cannot accept twice', () {
      expect(Rules.canAccept(invite(stage: 'accepted'), cg), isFalse);
    });
  });

  group('canWithdraw', () {
    test('the sender can withdraw a pending invite', () {
      expect(Rules.canWithdraw(invite(), bb), isTrue);
    });

    test('the recipient cannot withdraw', () {
      expect(Rules.canWithdraw(invite(), cg), isFalse);
    });

    test('cannot withdraw once accepted', () {
      expect(Rules.canWithdraw(invite(stage: 'accepted'), bb), isFalse);
    });
  });
}
