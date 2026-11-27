import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';
import '../widgets/feedback_banner.dart';
import '../foodwise_theme.dart';
import '../models/food.dart';
import '../services/student_food_controller.dart';
import '../widgets/food_browse_widgets.dart';

class HomeScreen extends StatefulWidget {
  final StudentFoodController controller;
  final Future<Map<String, dynamic>?> profileFuture;
  const HomeScreen({
    super.key,
    required this.controller,
    required this.profileFuture,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String? _category;
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _category = null;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) => FoodWisePage(
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => FutureBuilder<List<Food>>(
        future: widget.controller.foodFuture,
        builder: (context, snapshot) {
          final foods = snapshot.data ?? <Food>[];
          final categories =
              foods
                  .map((f) => f.categoryName)
                  .where((c) => c.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final active = categories.contains(_category) ? _category : null;
          final filtered = foods
              .where(
                (food) =>
                    (active == null || food.categoryName == active) &&
                    matchesFoodSearch(food, _query),
              )
              .toList();
          return RefreshIndicator(
            color: FoodWiseColors.orange,
            onRefresh: widget.controller.refresh,
            child: ListView(
              key: const PageStorageKey('foodwise-home'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _WelcomeBanner(profileFuture: widget.profileFuture),
                const SizedBox(height: 20),
                FoodSearchField(
                  controller: _search,
                  hint: 'Search meals or food providers',
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 20),
                if (widget.controller.favoritesFailed)
                  FeedbackBanner(
                    feedback: const FeedbackData(
                      title: 'Favorites could not sync',
                      message: 'You can still browse meals. Retry to restore your saved meals.',
                      type: FeedbackType.warning,
                      actionLabel: 'Retry',
                    ),
                    onAction: widget.controller.loadFavorites,
                  ),
                if (snapshot.connectionState == ConnectionState.waiting) ...[
                  const LinearProgressIndicator(color: FoodWiseColors.orange),
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Loading meals…')),
                  ),
                ] else if (snapshot.hasError) ...[
                  FeedbackBanner(
                    feedback: FeedbackData(
                      title: 'Meals could not load',
                      message: AppFeedback.fromError(
                        snapshot.error!,
                        fallback: 'Check your connection and try again.',
                      ).message,
                      type: FeedbackType.error,
                      actionLabel: 'Try again',
                    ),
                    onAction: widget.controller.refresh,
                  ),
                ] else if (foods.isEmpty) ...[
                  BrowseState(
                    icon: Icons.restaurant_rounded,
                    title: 'No meals available yet',
                    message: 'Check back later for new campus meals.',
                    actionLabel: 'Refresh',
                    onAction: widget.controller.refresh,
                  ),
                ] else ...[
                  const Text(
                    'Explore categories',
                    style: TextStyle(
                      fontSize: 19,
                      color: FoodWiseColors.charcoal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(
                        'All',
                        active == null,
                        () => setState(() => _category = null),
                      ),
                      for (final category in categories)
                        _chip(
                          category,
                          active == category,
                          () => setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Campus meals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: FoodWiseColors.charcoal,
                    ),
                  ),
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'meal' : 'meals'} found',
                    style: const TextStyle(color: FoodWiseColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    BrowseState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching meals',
                      message: 'Try another search or category.',
                      actionLabel: 'Clear filters',
                      onAction: _clearFilters,
                    )
                  else
                    FoodGrid(foods: filtered, controller: widget.controller),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback select) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => select(),
    selectedColor: FoodWiseColors.lightOrange,
    backgroundColor: Colors.white,
    labelStyle: TextStyle(
      color: selected ? FoodWiseColors.deepOrange : FoodWiseColors.charcoal,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _WelcomeBanner extends StatelessWidget {
  final Future<Map<String, dynamic>?> profileFuture;
  const _WelcomeBanner({required this.profileFuture});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: profileFuture,
    builder: (context, snapshot) {
      final name = (snapshot.data?['full_name']?.toString() ?? '').trim();
      final firstName = name.isEmpty
          ? 'there'
          : name.split(RegExp(r'\s+')).first;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FoodWiseColors.paleOrange,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: FoodWiseColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR CAMPUS FOOD GUIDE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: FoodWiseColors.deepOrange,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hey, $firstName!',
                    style: const TextStyle(
                      fontSize: 26,
                      color: FoodWiseColors.charcoal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Discover delicious and affordable meals around campus.',
                    style: TextStyle(
                      color: FoodWiseColors.charcoal,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.ramen_dining_rounded,
              color: FoodWiseColors.deepOrange,
              size: 44,
            ),
          ],
        ),
      );
    },
  );
}
