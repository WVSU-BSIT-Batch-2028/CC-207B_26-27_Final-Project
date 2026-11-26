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

// An accepted room. withTerms = BudgetBuddy has proposed terms.
Exchange room({bool withTerms = true, List<String>? agreedBy}) => Exchange(
  id: 'x1',
  senderId: bb,
  recipientId: cg,
  note: 'Could your students test our signup?',
  stage: 'accepted',
  goal: withTerms ? 'Test our signup flow' : '',
  testerCount: withTerms ? 3 : 0,
  deliverables: withTerms ? 'A short feedback note' : '',
  termsAgreedBy: agreedBy ?? (withTerms ? [bb] : []),
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

    test('agreeTerms once BudgetBuddy has proposed terms', () {
      expect(Rules.nextPartnerAction(room(), cg), 'agreeTerms');
    });

    test('nothing when the partner already agreed to proposed terms', () {
      expect(Rules.nextPartnerAction(room(agreedBy: [cg]), cg), isNull);
    });

    test('nothing before BudgetBuddy checks step 1', () {
      final e = room(agreedBy: [bb, cg])..stage = 'termsAgreed';
      expect(Rules.nextPartnerAction(e, cg), isNull);
    });

    test('confirmStep1 after BudgetBuddy checks step 1', () {
      final e = room(agreedBy: [bb, cg])..stage = 'termsAgreed';
      e.step1ConfirmedBy.add(bb);
      expect(Rules.nextPartnerAction(e, cg), 'confirmStep1');
      e.step1ConfirmedBy.add(cg);
      expect(Rules.nextPartnerAction(e, cg), isNull);
    });

    test('confirmStep2 after BudgetBuddy checks with a feedback note', () {
      final e = room(agreedBy: [bb, cg])..stage = 'termsAgreed';
      e.step1ConfirmedBy.addAll([bb, cg]);
      e.feedbackNote = 'Feedback';
      expect(Rules.nextPartnerAction(e, cg), isNull);
      e.step2ConfirmedBy.add(bb);
      expect(Rules.nextPartnerAction(e, cg), 'confirmStep2');
    });

    test('review as soon as the room launches, once per partner', () {
      final e = room(agreedBy: [bb, cg])..stage = 'termsAgreed';
      expect(Rules.nextPartnerAction(e, cg), isNull);

      e.stage = 'launched';
      expect(Rules.nextPartnerAction(e, cg), 'review');

      e.ratings[cg] = 5;
      expect(Rules.nextPartnerAction(e, cg), isNull);
    });
  });

  group('validTerms', () {
    test('blank goal is not valid', () {
      expect(Rules.validTerms('  ', 3, 'A short feedback note'), isFalse);
    });

    test('0 testers is not valid', () {
      expect(Rules.validTerms('Test our signup', 0, 'Feedback'), isFalse);
    });

    test('blank deliverables is not valid', () {
      expect(Rules.validTerms('Test our signup', 3, ''), isFalse);
    });

    test('good terms are valid', () {
      expect(Rules.validTerms('Test our signup', 3, 'Feedback'), isTrue);
    });
  });

  group('canEditTerms', () {
    test('both startups in the room can edit', () {
      expect(Rules.canEditTerms(room(), bb), isTrue);
      expect(Rules.canEditTerms(room(), cg), isTrue);
    });

    test('an outsider cannot edit', () {
      expect(Rules.canEditTerms(room(), pp), isFalse);
    });

    test('cannot edit once the terms are agreed', () {
      final locked = room(agreedBy: [bb, cg])..stage = 'termsAgreed';
      expect(Rules.canEditTerms(locked, bb), isFalse);
    });
  });

  group('canAgreeTerms', () {
    test('the partner can agree to proposed terms', () {
      expect(Rules.canAgreeTerms(room(), cg), isTrue);
    });

    test('no one can agree before terms exist', () {
      expect(Rules.canAgreeTerms(room(withTerms: false), cg), isFalse);
      expect(Rules.canAgreeTerms(room(withTerms: false), bb), isFalse);
    });

    test('cannot agree twice', () {
      expect(Rules.canAgreeTerms(room(), bb), isFalse);
    });

    test('an outsider cannot agree', () {
      expect(Rules.canAgreeTerms(room(), pp), isFalse);
    });
  });

  group('termsLocked', () {
    test('not locked with one agreement', () {
      expect(Rules.termsLocked(room(agreedBy: [bb])), isFalse);
      expect(Rules.termsLocked(room(agreedBy: [cg])), isFalse);
    });

    test('locked once both startups agree', () {
      expect(Rules.termsLocked(room(agreedBy: [bb, cg])), isTrue);
    });

    test('an outsider in the list does not count', () {
      expect(Rules.termsLocked(room(agreedBy: [bb, pp])), isFalse);
    });
  });

  group('canReview', () {
    test(
      'allows participants only after launch and only for ratings 1 to 5',
      () {
        final e = room()..stage = 'termsAgreed';
        expect(Rules.canReview(e, bb, 4), isFalse);

        e.stage = 'launched';
        expect(Rules.canReview(e, bb, 1), isTrue);
        expect(Rules.canReview(e, cg, 5), isTrue);
        expect(Rules.canReview(e, bb, 0), isFalse);
        expect(Rules.canReview(e, bb, 6), isFalse);
        expect(Rules.canReview(e, 'printpal', 4), isFalse);
      },
    );

    test('blocks a second review from the same startup', () {
      final e = room()..stage = 'launched';
      e.ratings[bb] = 4;
      expect(Rules.canReview(e, bb, 5), isFalse);
      expect(Rules.canReview(e, cg, 5), isTrue);
    });
  });

  group('canSeeReview', () {
    test(
      'before release, only the submitted review is visible to its author',
      () {
        final e = room()..stage = 'launched';
        e.ratings[bb] = 4;
        expect(Rules.canSeeReview(e, bb, bb), isTrue);
        expect(Rules.canSeeReview(e, bb, cg), isFalse);
        expect(Rules.canSeeReview(e, cg, bb), isFalse);
        expect(Rules.canSeeReview(e, cg, cg), isFalse);
      },
    );

    test('after release, both participants can see both reviews', () {
      final e = room()..stage = 'reviewed';
      e.ratings.addAll({bb: 4, cg: 5});

      for (final author in [bb, cg]) {
        expect(Rules.canSeeReview(e, bb, author), isTrue);
        expect(Rules.canSeeReview(e, cg, author), isTrue);
        expect(Rules.canSeeReview(e, 'printpal', author), isFalse);
      }
      expect(Rules.canSeeReview(e, bb, 'printpal'), isFalse);
    });
  });

  group('canConfirmStep', () {
    late Exchange e;

    setUp(() {
      e = room(agreedBy: [bb, cg])..stage = 'termsAgreed';
    });

    test('blocks confirmation before terms are locked', () {
      expect(Rules.canConfirmStep(room(), 1, bb, ''), isFalse);
    });

    test('blocks step 2 until both confirm step 1', () {
      e.step1ConfirmedBy.add(bb);
      expect(Rules.canConfirmStep(e, 2, cg, 'Feedback'), isFalse);
    });

    test('first step 2 confirmation requires a note', () {
      e.step1ConfirmedBy.addAll([bb, cg]);
      expect(Rules.canConfirmStep(e, 2, bb, '  '), isFalse);
      expect(Rules.canConfirmStep(e, 2, bb, 'Feedback'), isTrue);
    });

    test('second step 2 confirmation needs no note', () {
      e.step1ConfirmedBy.addAll([bb, cg]);
      e.step2ConfirmedBy.add(bb);
      e.feedbackNote = 'Feedback';
      expect(Rules.canConfirmStep(e, 2, cg, ''), isTrue);
    });

    test('blocks confirming the same step twice', () {
      e.step1ConfirmedBy.add(bb);
      expect(Rules.canConfirmStep(e, 1, bb, ''), isFalse);
      expect(Rules.canConfirmStep(e, 1, cg, ''), isTrue);
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
