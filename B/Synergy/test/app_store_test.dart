import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synergy_flutter/app_store.dart';
import 'package:synergy_flutter/models.dart';
import 'package:synergy_flutter/rules.dart';

const bb = 'budgetbuddy';
const cg = campusGrocerId;

// A loaded store with an accepted room: BudgetBuddy invited Campus Grocer
Future<(AppStore, Exchange)> acceptedRoom() async {
  final store = AppStore();
  addTearDown(store.dispose);
  await store.load();
  await store.sendInvite(bb, cg, 'Could your students test our signup?');
  final e = store.exchanges.single;
  await store.acceptInvite(e, cg);
  return (store, e);
}

// BudgetBuddy's proposed terms
Future<bool> bbSaves(AppStore store, Exchange e) => store.saveTerms(
  e,
  bb,
  'Test our signup flow',
  3,
  'One week',
  'A short feedback note',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first load gives the three sample startups', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.load();

    expect(store.startups.map((s) => s.name), [
      'BudgetBuddy',
      'Campus Grocer',
      'PrintPal',
    ]);
  });

  test('update saves changes for a new store', () async {
    final store = AppStore();
    final reloaded = AppStore();
    addTearDown(store.dispose);
    addTearDown(reloaded.dispose);
    await store.load();
    await store.update(() {
      store.startups.first.name = 'Updated BudgetBuddy';
      store.startups.first.savedIds.add('campusgrocer');
    });
    await reloaded.load();

    expect(reloaded.startups.first.name, 'Updated BudgetBuddy');
    expect(reloaded.startups.first.savedIds, ['campusgrocer']);
    expect(
      reloaded.startups.map((s) => s.toJson()).toList(),
      store.startups.map((s) => s.toJson()).toList(),
    );
  });

  test('reset restores the three samples and clears saved changes', () async {
    final store = AppStore();
    final reloaded = AppStore();
    addTearDown(store.dispose);
    addTearDown(reloaded.dispose);
    await store.load();
    await store.update(() {
      store.startups.first.name = 'Changed';
      store.startups.removeLast();
    });
    await store.reset();

    final samples = sampleStartups().map((s) => s.toJson()).toList();
    expect(store.startups.map((s) => s.toJson()).toList(), samples);
    await reloaded.load();
    expect(reloaded.startups.map((s) => s.toJson()).toList(), samples);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('synergy'), isFalse);
  });

  test('both startups confirm each milestone before launch', () async {
    final (store, e) = await acceptedRoom();
    await bbSaves(store, e);
    expect(await store.confirmStep(e, 1, bb), isFalse);
    expect(e.step1ConfirmedBy, isEmpty);
    await store.agreeTerms(e, cg);

    expect(await store.confirmStep(e, 1, bb), isTrue);
    expect(Rules.progress(e), 0);
    expect(await store.confirmStep(e, 1, cg), isTrue);
    expect(Rules.progress(e), 1);

    expect(await store.confirmStep(e, 2, bb, note: 'First note'), isTrue);
    expect(Rules.progress(e), 1);
    expect(e.stage, 'termsAgreed');
    expect(await store.confirmStep(e, 2, cg, note: 'Second note'), isTrue);
    expect(Rules.progress(e), 2);
    expect(e.stage, 'launched');
    expect(e.feedbackNote, 'First note');

    final reloaded = AppStore();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    final saved = reloaded.exchanges.single;
    expect(saved.step1ConfirmedBy, [bb, cg]);
    expect(saved.step2ConfirmedBy, [bb, cg]);
    expect(saved.feedbackNote, 'First note');
    expect(saved.stage, 'launched');
  });

  group('terms', () {
    test('A saves → termsAgreedBy is [A]', () async {
      final (store, e) = await acceptedRoom();

      expect(await bbSaves(store, e), isTrue);
      expect(e.termsAgreedBy, [bb]);
      expect(e.testerCount, 3);
      expect(e.stage, 'accepted'); // not locked yet
    });

    test('B agrees → stage is termsAgreed, even after a reload', () async {
      final (store, e) = await acceptedRoom();
      await bbSaves(store, e);

      expect(await store.agreeTerms(e, cg), isTrue);
      expect(e.termsAgreedBy, [bb, cg]);
      expect(e.stage, 'termsAgreed');

      final reloaded = AppStore();
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.exchanges.single.stage, 'termsAgreed');
      expect(reloaded.exchanges.single.termsAgreedBy, [bb, cg]);
    });

    test('B saved first, then A saves → only [A]', () async {
      final (store, e) = await acceptedRoom();
      await store.saveTerms(e, cg, 'Test our checkout', 2, '', 'Notes');
      expect(e.termsAgreedBy, [cg]);

      await bbSaves(store, e);
      expect(e.termsAgreedBy, [bb]);
      expect(e.goal, 'Test our signup flow');
    });

    test('invalid terms or locked terms are not saved', () async {
      final (store, e) = await acceptedRoom();
      expect(await store.saveTerms(e, bb, '', 3, '', 'Notes'), isFalse);
      expect(e.goal, isEmpty);

      await bbSaves(store, e);
      await store.agreeTerms(e, cg);
      expect(await store.saveTerms(e, cg, 'New goal', 5, '', 'Notes'), isFalse);
      expect(e.goal, 'Test our signup flow');
    });

    test('a save from before M3 (no terms fields) still loads', () async {
      final old = {
        'startups': [for (final s in sampleStartups()) s.toJson()],
        'exchanges': [
          {
            'id': 'x1',
            'senderId': bb,
            'recipientId': cg,
            'note': 'Hi',
            'stage': 'accepted',
          },
        ],
      };
      SharedPreferences.setMockInitialValues({'synergy': jsonEncode(old)});
      final store = AppStore();
      addTearDown(store.dispose);
      await store.load();

      final e = store.exchanges.single;
      expect(e.goal, '');
      expect(e.testerCount, 0);
      expect(e.termsAgreedBy, isEmpty);
      expect(e.step1ConfirmedBy, isEmpty);
      expect(e.step2ConfirmedBy, isEmpty);
      expect(e.feedbackNote, isEmpty);
      // Terms can now be added to the old exchange
      expect(await bbSaves(store, e), isTrue);
      expect(await store.agreeTerms(e, cg), isTrue);
      expect(e.stage, 'termsAgreed');
    });
  });
}
