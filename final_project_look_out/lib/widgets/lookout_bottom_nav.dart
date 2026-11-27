import 'package:flutter/material.dart';

class LookOutBottomNav extends StatelessWidget {
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  const LookOutBottomNav({
    super.key,
    this.destinations = const <NavigationDestination>[],
    this.selectedIndex = 0,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    assert(destinations.length <= 5);
    assert(selectedIndex >= 0 && selectedIndex < destinations.length);

    return NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      destinations: destinations,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected ?? (_) {},
    );
  }
}
