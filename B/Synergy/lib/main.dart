import 'package:flutter/material.dart';

import 'app_store.dart';
import 'screens/exchanges_screen.dart';
import 'screens/sign_in_screen.dart';
import 'widgets/demo_controls.dart';

// Synergy brand colors
const teal = Color(0xFF00726F); // buttons and main color
const darkTeal = Color(0xFF004543); // navigation bar
const pale = Color(0xFFF2F4F1); // page background

void main() {
  runApp(const SynergyApp());
}

class SynergyApp extends StatefulWidget {
  const SynergyApp({super.key});

  @override
  State<SynergyApp> createState() => _SynergyAppState();
}

class _SynergyAppState extends State<SynergyApp> {
  final store = AppStore();
  late final Future<void> _loading = store.load(); // load once

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synergy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
        scaffoldBackgroundColor: pale,
        appBarTheme: const AppBarTheme(backgroundColor: pale),
        cardTheme: const CardThemeData(color: Colors.white),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: darkTeal,
          indicatorColor: teal,
          iconTheme: WidgetStatePropertyAll(IconThemeData(color: Colors.white)),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white),
          ),
        ),
      ),
      home: FutureBuilder(
        future: _loading,
        builder: (context, snapshot) {
          // Spinner while the save slot loads
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Could not load saved data: ${snapshot.error}'),
              ),
            );
          }
          // Redraws when someone signs in or out
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) => store.currentStartup == null
                ? SignInScreen(store: store)
                : HomeShell(store: store),
          );
        },
      ),
    );
  }
}

// The main screen: app bar, current page, and bottom navigation
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _page = 0; // which tab is open

  // Matches is still a placeholder
  List<Widget> get _pages => [
    const Center(child: Text('Matches')),
    ExchangesScreen(store: widget.store),
    ListView(children: [DemoControls(store: widget.store)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Logo and the signed-in startup's name
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/synergy-logo.png', height: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.store.currentStartup?.name ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.store.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _pages[_page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (i) => setState(() => _page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Exchanges',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'My startup',
          ),
        ],
      ),
    );
  }
}
