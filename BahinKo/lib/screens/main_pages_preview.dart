import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';

class BahinKoPreviewApp extends StatelessWidget {
  const BahinKoPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BahinKo',
    theme: buildAppTheme(),
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) {
        final appWidth = constraints.maxWidth < 430
            ? constraints.maxWidth
            : 430.0;

        return ColoredBox(
          color: const Color(0xFFEFF3F1),
          child: Center(
            child: SizedBox(
              width: appWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    ),
    home: const MainPagesPreview(),
  );
}

class MainPagesPreview extends StatefulWidget {
  const MainPagesPreview({super.key});

  @override
  State<MainPagesPreview> createState() => _MainPagesPreviewState();
}

class _MainPagesPreviewState extends State<MainPagesPreview> {
  int _selectedTab = 0;

  void _showPreviewMessage(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$action is shown as a UI preview.')),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _selectedTab,
        children: [
          const _HomePage(),
          const _StatisticsPage(),
          const _HistoryPage(),
          const _ProfilePage(),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Scan receipt',
      onPressed: () => _showPreviewMessage('Receipt scanning'),
      backgroundColor: green,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: const Icon(Icons.qr_code_scanner),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          _NavItem(
            icon: Icons.bar_chart,
            label: 'Stats',
            selected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          const SizedBox(width: 48),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'History',
            selected: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: _selectedTab == 3,
            onTap: () => setState(() => _selectedTab = 3),
          ),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? green : muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 42),
              child: _BalanceHeader(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: _QuickActions(
                onAction: (action) => _showMessage(context, action),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Group Categories',
                action: 'See all',
                onAction: () => _showMessage(context, 'All categories'),
              ),
              const SizedBox(height: 12),
              const _CategoryGrid(),
              const SizedBox(height: 8),
              _SectionHeader(
                title: 'Active Groups',
                action: 'Join  ·  + New group',
                onAction: () => _showMessage(context, 'Groups'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _GroupCard(
                      name: 'Weekend Trip',
                      details: '4 members · 2 unpaid',
                      total: '₱ 3,250.00',
                      highlighted: true,
                    ),
                    SizedBox(width: 12),
                    _GroupCard(
                      name: 'Apartment Bills',
                      details: '3 members · 1 unpaid',
                      total: '₱ 1,840.00',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showMessage(BuildContext context, String action) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$action is shown as a UI preview.')),
    );
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 64),
    decoration: const BoxDecoration(
      gradient: brandGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HeaderIcon(
              icon: Icons.person_outline,
              tooltip: 'Profile',
              onTap: () => _showMessage(context, 'Profile'),
            ),
            _HeaderIcon(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              onTap: () => _showMessage(context, 'Notifications'),
            ),
          ],
        ),
        const Text('Net balance', style: TextStyle(color: Colors.white70)),
        const Text(
          '₱ 2,450.00',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            _BalanceChip('Owed to you  ₱3,000', lime, deep),
            _BalanceChip('You owe  ₱550', Colors.white, unpaidFg),
          ],
        ),
      ],
    ),
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white24,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    ),
  );
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip(this.label, this.color, this.foreground);

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
    backgroundColor: color,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickAction(Icons.qr_code_scanner, 'Scan', onAction),
        _QuickAction(Icons.add, 'Add', onAction),
        _QuickAction(
          Icons.account_balance_wallet_outlined,
          'Settle Up',
          onAction,
        ),
        _QuickAction(Icons.history, 'History', onAction),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onAction);

  final IconData icon;
  final String label;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onAction(label),
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: mint,
            foregroundColor: green,
            child: Icon(icon),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _categories = [
    (Icons.restaurant_outlined, 'Dinner'),
    (Icons.home_outlined, 'Boarding'),
    (Icons.flight_outlined, 'Trips'),
    (Icons.bolt_outlined, 'Utilities'),
    (Icons.repeat, 'Subscriptions'),
    (Icons.shopping_cart_outlined, 'Groceries'),
    (Icons.receipt_long_outlined, 'Bills'),
  ];

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    childAspectRatio: 0.9,
    children: [
      for (final (icon, label) in _categories)
        InkWell(
          onTap: () => _showMessage(context, 'Create $label group'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: border),
                ),
                child: Icon(icon, color: green),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: AppText.section)),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          foregroundColor: green,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(action),
      ),
    ],
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.name,
    required this.details,
    required this.total,
    this.highlighted = false,
  });

  final String name;
  final String details;
  final String total;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? Colors.white : deep;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: highlighted ? brandGradient : null,
        color: highlighted ? null : lime,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(18, color: foreground),
          ),
          Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(total, style: AppText.money(22, color: foreground)),
        ],
      ),
    );
  }
}

class _StatisticsPage extends StatelessWidget {
  const _StatisticsPage();

  static const _months = [
    ('Jan', 0.18, 0.25),
    ('Feb', 0.3, 0.22),
    ('Mar', 0.42, 0.34),
    ('Apr', 0.27, 0.38),
    ('May', 0.5, 0.43),
    ('Jun', 0.35, 0.48),
    ('Jul', 0.62, 0.55),
    ('Aug', 0.45, 0.39),
    ('Sep', 0.72, 0.61),
    ('Oct', 0.55, 0.74),
    ('Nov', 0.9, 0.78),
    ('Dec', 0.24, 0.2),
  ];

  @override
  Widget build(BuildContext context) => _PageScroll(
    title: 'Statistics',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total owed to you', style: AppText.caption),
        Text('₱ 3,000.00', style: AppText.money(32, color: deep)),
        const SizedBox(height: 6),
        const _BalanceChip('You owe ₱550.00', unpaidBg, unpaidFg),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Text('Overview', style: AppText.section)),
            _Legend(color: green, label: 'Your share'),
            const SizedBox(width: 10),
            _Legend(color: const Color(0xFF5ED38A), label: 'You paid'),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 170,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final (month, share, paid) in _months)
                _MonthBars(month: month, share: share, paid: paid),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _StatsTile(
                label: 'Collected',
                amount: '₱ 4,820.00',
                color: deep,
                icon: Icons.arrow_downward,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatsTile(
                label: 'Paid out',
                amount: '₱ 2,370.00',
                color: green,
                icon: Icons.arrow_upward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Spending by category', style: AppText.section),
              const Text('Your share, all groups', style: AppText.caption),
              const SizedBox(height: 10),
              const _CategoryPercentRow(
                label: 'Home',
                percent: 42,
                color: green,
              ),
              const _CategoryPercentRow(
                label: 'Trips',
                percent: 28,
                color: deep,
              ),
              const _CategoryPercentRow(
                label: 'Dinner',
                percent: 18,
                color: orange,
              ),
              const _CategoryPercentRow(
                label: 'Utilities',
                percent: 12,
                color: purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _showMessage(context, 'Personal ledger'),
            child: const Text('Open Personal Ledger'),
          ),
        ),
      ],
    ),
  );
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.month,
    required this.share,
    required this.paid,
  });

  final String month;
  final double share;
  final double paid;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Bar(share, green),
          const SizedBox(width: 3),
          _Bar(paid, const Color(0xFF5ED38A)),
        ],
      ),
      const SizedBox(height: 6),
      Text(month, style: const TextStyle(fontSize: 9, color: muted)),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: (120 * fraction).clamp(2, 120).toDouble(),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 4, backgroundColor: color),
      const SizedBox(width: 4),
      Text(label, style: AppText.caption),
    ],
  );
}

class _StatsTile extends StatelessWidget {
  const _StatsTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white24,
          foregroundColor: Colors.white,
          child: Icon(icon, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _CategoryPercentRow extends StatelessWidget {
  const _CategoryPercentRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: mint,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _HistoryPage extends StatefulWidget {
  const _HistoryPage();

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  String _filter = 'All';
  String _query = '';

  static const _items = [
    (
      'Expenses',
      Icons.restaurant_outlined,
      'Dinner at Lola’s',
      'Weekend Trip · 9:41 AM',
      '₱ 1,250.00',
    ),
    (
      'Expenses',
      Icons.home_outlined,
      'Electric bill',
      'Apartment Bills · Yesterday, 6:20 PM',
      '₱ 2,400.00',
    ),
    (
      'Payments',
      Icons.local_grocery_store_outlined,
      'Groceries',
      'Apartment Bills · Nov 22, 12:05 PM',
      '₱ 860.00',
    ),
    (
      'Reminders',
      Icons.directions_car_outlined,
      'Ride to Tagaytay',
      'Weekend Trip · Nov 20, 8:32 AM',
      '₱ 950.00',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((item) {
      final matchesFilter = _filter == 'All' || item.$1 == _filter;
      final query = _query.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          item.$3.toLowerCase().contains(query) ||
          item.$4.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    });

    return _PageScroll(
      title: 'Activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search activity',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in [
                  'All',
                  'Expenses',
                  'Payments',
                  'Reminders',
                  'Edits',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: filter,
                      selected: _filter == filter,
                      onSelected: () => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('This week', style: AppText.section),
          const SizedBox(height: 8),
          for (final item in visible)
            _HistoryTile(
              icon: item.$2,
              title: item.$3,
              subtitle: item.$4,
              amount: item.$5,
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    selectedColor: mint,
    side: BorderSide(color: selected ? green : border),
    labelStyle: TextStyle(
      color: selected ? deep : muted,
      fontSize: 12,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: mint,
          foregroundColor: green,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _autoDelete = true;
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) => _PageScroll(
    title: 'Profile',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileCard(
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mint,
                    border: Border.all(color: green, width: 2),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex Santos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('@alexsantos · 2 groups', style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: _WalletChip(name: 'GCash')),
                SizedBox(width: 8),
                Expanded(child: _WalletChip(name: 'Maya')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileCard(
          children: [
            _ProfileSetting(
              icon: Icons.lock_outline,
              title: 'App lock',
              subtitle: 'PIN or fingerprint',
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'On',
                    style: TextStyle(color: green, fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.chevron_right, color: muted),
                ],
              ),
              onTap: () => _showMessage(context, 'App lock'),
            ),
            _ProfileSetting(
              icon: Icons.image_outlined,
              title: 'Auto-delete receipt photos',
              subtitle: 'After 30 days',
              trailing: Switch(
                value: _autoDelete,
                activeThumbColor: Colors.white,
                activeTrackColor: green,
                onChanged: (value) => setState(() => _autoDelete = value),
              ),
            ),
            _ProfileSetting(
              icon: Icons.notifications_none,
              title: 'Reminder settings',
              subtitle: 'Default tone, 1 day before due dates',
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => _showMessage(context, 'Reminder settings'),
            ),
            _ProfileSetting(
              icon: Icons.wifi_off,
              title: 'Offline mode',
              subtitle: _offlineMode
                  ? 'Changes stay on this phone'
                  : 'Sync groups when online',
              trailing: Switch(
                value: _offlineMode,
                activeThumbColor: Colors.white,
                activeTrackColor: green,
                onChanged: (value) => setState(() => _offlineMode = value),
              ),
            ),
            _ProfileSetting(
              icon: Icons.verified_user_outlined,
              title: 'Privacy and Trust',
              subtitle: 'How we protect your data',
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => _showMessage(context, 'Privacy and Trust'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileCard(
          padding: const EdgeInsets.all(4),
          dividers: false,
          children: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _showMessage(context, 'Log out'),
                style: TextButton.styleFrom(
                  foregroundColor: errorFg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Log out',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text('BahinKo v1.0 · prototype', style: AppText.caption),
        ),
      ],
    ),
  );
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: green,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Add $name',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: green,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.dividers = true,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final bool dividers;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: _cardDecoration(radius: 20),
    child: Column(children: dividers ? _withDividers(children) : children),
  );

  List<Widget> _withDividers(List<Widget> widgets) => [
    for (var i = 0; i < widgets.length; i++) ...[
      if (i > 0) const Divider(height: 1),
      widgets[i],
    ],
  ];
}

class _ProfileSetting extends StatelessWidget {
  const _ProfileSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    ),
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text(title, style: AppText.title)),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

BoxDecoration _cardDecoration({double radius = 16}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10)],
);
