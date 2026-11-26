import 'package:flutter/material.dart';

void main() => runApp(const LayoutPreviewApp());

class LayoutPreviewApp extends StatelessWidget {
  const LayoutPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BahinKo Layout Preview',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A9B7A)),
    ),
    home: const LayoutPreviewScreen(),
  );
}

class LayoutPreviewScreen extends StatefulWidget {
  const LayoutPreviewScreen({super.key});

  @override
  State<LayoutPreviewScreen> createState() => _LayoutPreviewScreenState();
}

class _LayoutPreviewScreenState extends State<LayoutPreviewScreen> {
  int _selectedTab = 0;

  static const _green = Color(0xFF0A9B7A);
  static const _deepGreen = Color(0xFF064E3B);
  static const _muted = Color(0xFF6B7C76);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _balanceHeader(),
                  _quickActions(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Group Categories'),
                        const SizedBox(height: 14),
                        _categoryGrid(),
                        const SizedBox(height: 26),
                        _sectionTitle('Active Groups'),
                        const SizedBox(height: 14),
                        _groupCard(
                          'Weekend Trip',
                          '4 members · 2 unpaid',
                          '₱ 3,250.00',
                          const Color(0xFF0A9B7A),
                        ),
                        const SizedBox(height: 12),
                        _groupCard(
                          'Apartment Bills',
                          '3 members · 1 unpaid',
                          '₱ 1,840.00',
                          const Color(0xFFA7F3A0),
                          darkText: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _bottomNavigation(),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {},
      backgroundColor: _green,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: const Icon(Icons.qr_code_scanner),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  );

  Widget _balanceHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_green, _deepGreen],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BahinKo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Net balance', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        const Text(
          '₱ 2,450.00',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            _balanceChip('Owed to you  ₱3,000', const Color(0xFFA7F3A0)),
            _balanceChip('You owe  ₱550', Colors.white),
          ],
        ),
      ],
    ),
  );

  Widget _balanceChip(String text, Color color) => Chip(
    label: Text(text, style: const TextStyle(fontSize: 11)),
    backgroundColor: color,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );

  Widget _quickActions() => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 4)),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _action(Icons.add, 'Add'),
        _action(Icons.account_balance_wallet_outlined, 'Settle Up'),
        _action(Icons.history, 'History'),
      ],
    ),
  );

  Widget _action(IconData icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        backgroundColor: const Color(0xFFE8F7F0),
        foregroundColor: _green,
        child: Icon(icon),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: Color(0xFF10201B),
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _categoryGrid() {
    const categories = [
      (Icons.home_outlined, 'Home'),
      (Icons.flight_outlined, 'Travel'),
      (Icons.restaurant_outlined, 'Food'),
      (Icons.groups_outlined, 'Other'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (icon, label) in categories)
          Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: _green),
              ),
              const SizedBox(height: 7),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
      ],
    );
  }

  Widget _groupCard(
    String name,
    String subtitle,
    String total,
    Color color, {
    bool darkText = false,
  }) {
    final foreground = darkText ? _deepGreen : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(color: foreground, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: foreground.withValues(alpha: 0.8), fontSize: 12)),
          const SizedBox(height: 18),
          Text(total, style: TextStyle(color: foreground, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _bottomNavigation() => BottomAppBar(
    color: Colors.white,
    shape: const CircularNotchedRectangle(),
    notchMargin: 7,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _navItem(Icons.home_outlined, 'Home', 0),
        _navItem(Icons.bar_chart, 'Stats', 1),
        const SizedBox(width: 46),
        _navItem(Icons.receipt_long_outlined, 'History', 2),
        _navItem(Icons.person_outline, 'Profile', 3),
      ],
    ),
  );

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? _green : _muted, size: 21),
            Text(
              label,
              style: TextStyle(
                color: selected ? _green : _muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
