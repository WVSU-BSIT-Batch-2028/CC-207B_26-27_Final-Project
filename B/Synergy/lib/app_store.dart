import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
// Browser uses sessionStorage, tests use memory
import 'session_stub.dart' if (dart.library.js_interop) 'session_web.dart';

class AppStore extends ChangeNotifier {
  List<Startup> startups = [];

  // The signed-in startup's ID (saved per browser tab)
  String? currentId;

  // The signed-in startup, or null if no one is signed in
  Startup? get currentStartup =>
      startups.where((s) => s.id == currentId).firstOrNull;

  Future<void> load() async {
    currentId = readFounderId();
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

  // Demo-only sign-in: plain email and password check
  bool signIn(String email, String password) {
    final cleanEmail = email.trim().toLowerCase();
    final match = startups
        .where((s) => s.email == cleanEmail && s.password == password)
        .firstOrNull;
    if (match == null) return false;
    _setCurrent(match.id);
    return true;
  }

  // Create a startup and sign in as it. False if the email is taken.
  Future<bool> register(String name, String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (startups.any((s) => s.email == cleanEmail)) return false;
    final startup = Startup(
      id: 'startup-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      password: password,
      name: name.trim(),
      // The rest is filled in later on My startup
      description: '',
      industry: '',
      stage: '',
      teamSize: 1,
      offerText: '',
      needText: '',
      offers: [],
      needs: [],
      savedIds: [],
    );
    await update(() => startups.add(startup));
    _setCurrent(startup.id);
    return true;
  }

  void signOut() => _setCurrent(null);

  // Remember who is signed in for this tab and redraw the screens
  void _setCurrent(String? id) {
    currentId = id;
    writeFounderId(id);
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
