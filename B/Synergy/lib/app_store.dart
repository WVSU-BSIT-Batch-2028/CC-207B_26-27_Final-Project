import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStore extends ChangeNotifier {
  List<Startup> startups = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('synergy');
    if (text == null) {
      startups = sampleStartups();
      return;
    }
    final data = jsonDecode(text) as Map<String, dynamic>;
    startups = [
      for (final s in data['startups'] as List)
        Startup.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<void> update(void Function() change) async {
    change();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'synergy',
      jsonEncode({
        'startups': [for (final s in startups) s.toJson()],
      }),
    );
    notifyListeners();
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('synergy');
    startups = sampleStartups();
    notifyListeners();
  }
}

List<Startup> sampleStartups() => [
  Startup(
    id: 'budgetbuddy',
    email: 'budgetbuddy@demo.test',
    password: 'demo123',
    name: 'BudgetBuddy',
    description: 'Helps students track spending and plan a budget.',
    industry: 'Fintech',
    stage: 'Prototype',
    teamSize: 3,
    offerText: 'We can review your app and give product feedback.',
    needText: 'We need students to test our onboarding.',
    offers: ['Product Feedback'],
    needs: ['Beta Testers'],
    savedIds: [],
  ),
  Startup(
    id: 'campusgrocer',
    email: 'campusgrocer@demo.test',
    password: 'demo123',
    name: 'Campus Grocer',
    description: 'Delivers affordable groceries to students on campus.',
    industry: 'E-commerce',
    stage: 'Pilot',
    teamSize: 4,
    offerText: 'We can recruit students to test your app.',
    needText: 'We need product feedback on our checkout.',
    offers: ['Beta Testers'],
    needs: ['Product Feedback'],
    savedIds: [],
  ),
  Startup(
    id: 'printpal',
    email: 'printpal@demo.test',
    password: 'demo123',
    name: 'PrintPal',
    description: 'Makes it easy to order and collect campus print jobs.',
    industry: 'Printing services',
    stage: 'Prototype',
    teamSize: 2,
    offerText: 'We can help build app features and fix technical issues.',
    needText: 'We need user research into student printing habits.',
    offers: ['Technical Development'],
    needs: ['User Research'],
    savedIds: [],
  ),
];
