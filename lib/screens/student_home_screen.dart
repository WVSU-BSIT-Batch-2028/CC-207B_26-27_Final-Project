import 'package:flutter/material.dart';

import 'navigation_screen.dart';

export 'food_detail_screen.dart' show FoodDetailScreen;

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentNavigationScreen();
  }
}
