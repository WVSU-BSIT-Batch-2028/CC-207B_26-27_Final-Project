// Lets any page inside the main screen switch to another tab, e.g. the
// dashboard's "See all" button opening the Demand tab. HomeScreen puts a
// HomeNav above all its pages; a page calls HomeNav.of(context)?.open(...).
//
// (An InheritedWidget is Flutter's way to share something with every
// widget below it without passing it through each constructor.)

import 'package:flutter/widgets.dart';

/// The tabs of the main screen. Not every role has every tab.
enum HomeTab {
  home,
  prices,
  myCrops,
  demand,
  market,
  requests,
  following,
  orders,
  messages,
}

/// Shares the "open this tab" action with the pages below HomeScreen.
class HomeNav extends InheritedWidget {
  const HomeNav({super.key, required this.open, required super.child});

  /// Switches the main screen to [tab] (does nothing if the role lacks it).
  final void Function(HomeTab tab) open;

  /// The nearest HomeNav, or null on screens outside the main screen.
  static HomeNav? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeNav>();

  @override
  bool updateShouldNotify(HomeNav oldWidget) => open != oldWidget.open;
}
