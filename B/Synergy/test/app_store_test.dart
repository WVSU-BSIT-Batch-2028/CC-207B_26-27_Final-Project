import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synergy_flutter/app_store.dart';

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
}
