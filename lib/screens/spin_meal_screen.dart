import 'package:flutter/material.dart';

import '../foodwise_theme.dart';
import '../widgets/food_browse_widgets.dart';

/// Placeholder only. Replace this widget with the group's Spin the Meal feature.
class SpinMealScreen extends StatelessWidget {
  const SpinMealScreen({super.key});
  @override
  Widget build(BuildContext context) => FoodWisePage(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'Spin the Meal',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: FoodWiseColors.charcoal,
          ),
        ),
        BrowseState(
          icon: Icons.casino_outlined,
          title: 'Coming soon',
          message: 'Not sure what to eat? This feature will help you discover a meal. It is still in development.',
        ),
      ],
    ),
  );
}
