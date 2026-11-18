import 'package:flutter/material.dart';
import 'package:websupark/screens/driver/driver_alerts_screen.dart';
import 'package:websupark/screens/driver/driver_assignment_screen.dart';
import 'package:websupark/screens/driver/driver_home_screen.dart';
import 'package:websupark/screens/driver/driver_vehicle_screen.dart';
import 'package:websupark/screens/driver/driver_violations_screen.dart';
import 'package:websupark/theme/app_colors.dart';

/// Frame of the driver interface: five pages with a bottom navigation bar.
/// Each tab shows one real screen (D1 to D5 in the prototype checklist).
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, this.initialIndex = 0});

  /// Which tab opens first (0 = Home ... 4 = Vehicle).
  final int initialIndex;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  // The tab currently shown. It changes when a tab is tapped.
  late int _index = widget.initialIndex;

  // One page per tab, in the same order as the navigation bar.
  final List<Widget> _pages = const [
    DriverHomeScreen(), // D1
    DriverAssignmentScreen(), // D2
    DriverAlertsScreen(), // D3
    DriverViolationsScreen(), // D4
    DriverVehicleScreen(), // D5
  ];

  @override
  Widget build(BuildContext context) {
    // The driver interface is designed for phones, so on a wide browser
    // window it stays a centered, phone-width column.
    return ColoredBox(
      color: AppColors.border,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Scaffold(
            // IndexedStack keeps every page alive, so switching tabs
            // does not lose what the user typed or scrolled.
            body: SafeArea(
              child: IndexedStack(index: _index, children: _pages),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_parking),
                  label: 'Assignment',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.warning_amber_outlined),
                  label: 'Violations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_car_outlined),
                  label: 'Vehicle',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}