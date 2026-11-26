import 'package:flutter_test/flutter_test.dart';
import 'package:synergy_flutter/app_store.dart';
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

  group('nextPartnerAction', () {
    test('accept when the partner has a pending invite', () {
      expect(Rules.nextPartnerAction(invite(), cg), 'accept');
    });

    test('nothing for the sender of the invite', () {
      expect(Rules.nextPartnerAction(invite(), bb), isNull);
    });

    test('nothing once accepted or declined', () {
      expect(Rules.nextPartnerAction(invite(stage: 'accepted'), cg), isNull);
      expect(Rules.nextPartnerAction(invite(stage: 'declined'), cg), isNull);
    });
  });

  group('matchFit', () {
    final budgetBuddy = sampleStartups().firstWhere((s) => s.id == bb);
    final campusGrocer = sampleStartups().firstWhere((s) => s.id == cg);

    // Campus Grocer with one extra need BudgetBuddy can't cover
    Startup grocerPlusResearch() => withTags(
      offers: ['Beta Testers'],
      needs: ['Product Feedback', 'User Research'],
    );

    test('sample pair scores 100', () {
      expect(Rules.matchFit(budgetBuddy, campusGrocer), 100);
      expect(Rules.matchFit(campusGrocer, budgetBuddy), 100);
    });

    test('extra need User Research drops it to 50', () {
      expect(Rules.matchFit(budgetBuddy, grocerPlusResearch()), 50);
    });

    test('one side with no needs scores 0', () {
      final noNeeds = withTags(offers: ['Beta Testers'], needs: []);
      expect(Rules.matchFit(budgetBuddy, noNeeds), 0);
      expect(Rules.matchFit(noNeeds, budgetBuddy), 0);
    });

    test('no overlap at all scores 0', () {
      final other = withTags(
        offers: ['Technical Development'],
        needs: ['User Research'],
      );
      expect(Rules.matchFit(budgetBuddy, other), 0);
    });

    test('2 of 3 needs covered rounds to 67', () {
      final a = withTags(
        offers: ['Product Feedback'],
        needs: ['Beta Testers', 'User Research', 'Technical Development'],
      );
      final b = withTags(
        offers: ['Beta Testers', 'User Research'],
        needs: ['Product Feedback'],
      );
      expect(Rules.matchFit(a, b), 67);
    });

    test('a repeated tag counts once', () {
      final twice = withTags(
        offers: ['Beta Testers'],
        needs: ['Product Feedback', 'Product Feedback'],
      );
      expect(Rules.matchFit(budgetBuddy, twice), 100);
    });

    test('theyOffer and youOffer show both directions', () {
      expect(Rules.theyOffer(budgetBuddy, campusGrocer), ['Beta Testers']);
      expect(Rules.youOffer(budgetBuddy, campusGrocer), ['Product Feedback']);
    });

    test('theyStillNeed shows the gap in the 50% case', () {
      expect(Rules.theyStillNeed(budgetBuddy, grocerPlusResearch()), [
        'User Research',
      ]);
      expect(Rules.theyStillNeed(budgetBuddy, campusGrocer), isEmpty);
    });
  });
}

// A test startup with only the tags filled in
Startup withTags({required List<String> offers, required List<String> needs}) =>
    Startup(
      id: 'test',
      email: 'test@demo.test',
      password: 'demo123',
      name: 'Test',
      description: '',
      industry: '',
      stage: '',
      teamSize: 1,
      offerText: '',
      needText: '',
      offers: offers,
      needs: needs,
      savedIds: [],
    );
