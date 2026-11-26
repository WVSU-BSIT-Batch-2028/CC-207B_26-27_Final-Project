import 'package:flutter/material.dart';

// Synergy brand colors
const teal = Color(0xFF00726F); // buttons and main color
const darkTeal = Color(0xFF004543); // navigation bar
const pale = Color(0xFFF2F4F1); // page background

void main() {
  runApp(const SynergyApp());
}

class SynergyApp extends StatelessWidget {
  const SynergyApp({super.key});

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
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: Colors.white),
          ),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

// The main screen: app bar, current page, and bottom navigation
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _page = 0; // which tab is open

  // Placeholder pages for now
  static const _pages = [
    Center(child: Text('Matches')),
    Center(child: Text('Exchanges')),
    Center(child: Text('My startup')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/synergy-logo.png', height: 32),
            const SizedBox(width: 10),
            const Text('Synergy'),
          ],
        ),
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
