import 'package:flutter/material.dart';
import 'package:websupark/theme/app_colors.dart';
import 'package:websupark/widgets/placeholder_page.dart';

/// Frame of the head-security interface: a dark sidebar on the left
/// and the selected page on the right (desktop layout).
/// The head-security owner replaces each PlaceholderPage with the real
/// screen (H1 to H6 in the prototype checklist).
class HeadShell extends StatefulWidget {
  const HeadShell({super.key, this.initialIndex = 0});

  /// Which sidebar item opens first (0 = Central Overview ... 5 = Outside Vehicles).
  final int initialIndex;

  @override
  State<HeadShell> createState() => _HeadShellState();
}

class _HeadShellState extends State<HeadShell> {
  // The sidebar item currently selected.
  late int _index = widget.initialIndex;

  // One page per sidebar item, in the same order as the destinations below.
  final List<Widget> _pages = const [
    PlaceholderPage(
      title: 'Central Overview',
      screenCode: 'H1',
      owner: 'Head security owner',
    ),
    PlaceholderPage(
      title: 'Vehicle Database',
      screenCode: 'H2',
      owner: 'Head security owner',
    ),
    PlaceholderPage(
      title: 'Parking Monitoring',
      screenCode: 'H3',
      owner: 'Head security owner',
    ),
    PlaceholderPage(
      title: 'Violation Management',
      screenCode: 'H4',
      owner: 'Head security owner',
    ),
    PlaceholderPage(
      title: 'Yellow Pass Monitoring',
      screenCode: 'H5',
      owner: 'Head security owner',
    ),
    PlaceholderPage(
      title: 'Outside Vehicles',
      screenCode: 'H6',
      owner: 'Head security owner',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar. "extended" shows the text labels next to the icons.
          NavigationRail(
            extended: true,
            minExtendedWidth: 250,
            backgroundColor: AppColors.sidebar,
            indicatorColor: AppColors.action,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            // Title block at the top of the sidebar.
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAIN GATE',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    'Security Command',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: Text('Central Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.directions_car_outlined),
                label: Text('Vehicle Database'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                label: Text('Parking Monitoring'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warning_amber_outlined),
                label: Text('Violation Management'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule),
                label: Text('Yellow Pass Monitoring'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                label: Text('Outside Vehicles'),
              ),
            ],
          ),
          // The selected page fills the rest of the window.
          // IndexedStack keeps every page alive when switching.
          Expanded(child: IndexedStack(index: _index, children: _pages)),
        ],
      ),
    );
  }
}