import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';
import '../widgets/feedback_banner.dart';
import '../foodwise_theme.dart';
import '../models/food.dart';
import '../services/student_food_controller.dart';
import '../widgets/food_browse_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  final StudentFoodController controller;
  final VoidCallback onBrowse;
  const FavoritesScreen({
    super.key,
    required this.controller,
    required this.onBrowse,
  });
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FoodWisePage(
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => FutureBuilder<List<Food>>(
        future: widget.controller.foodFuture,
        builder: (context, snapshot) {
          final saved = (snapshot.data ?? <Food>[])
              .where(widget.controller.isFavorite)
              .toList();
          final filtered = saved
              .where((food) => matchesFoodSearch(food, _query))
              .toList();
          return RefreshIndicator(
            color: FoodWiseColors.orange,
            onRefresh: widget.controller.refresh,
            child: ListView(
              key: const PageStorageKey('foodwise-favorites'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const Text(
                  'Favorites',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: FoodWiseColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All your saved meals in one place.',
                  style: TextStyle(color: FoodWiseColors.muted),
                ),
                const SizedBox(height: 20),
                if (widget.controller.favoritesLoading)
                  const LinearProgressIndicator(color: FoodWiseColors.orange)
                else if (widget.controller.favoritesFailed ||
                    !widget.controller.favoritesReady)
                  FeedbackBanner(
                    feedback: const FeedbackData(
                      title: 'Saved meals could not sync',
                      message: 'Check your connection and try again.',
                      type: FeedbackType.error,
                      actionLabel: 'Try again',
                    ),
                    onAction: widget.controller.loadFavorites,
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(color: FoodWiseColors.orange)
                else if (snapshot.hasError)
                  FeedbackBanner(
                    feedback: FeedbackData(
                      title: 'Favorites could not load',
                      message: AppFeedback.fromError(
                        snapshot.error!,
                        fallback: 'Check your connection and try again.',
                      ).message,
                      type: FeedbackType.error,
                      actionLabel: 'Try again',
                    ),
                    onAction: widget.controller.refresh,
                  )
                else if (saved.isEmpty)
                  BrowseState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favorites yet',
                    message: 'Tap the heart on any meal to save it here.',
                    actionLabel: 'Explore meals',
                    onAction: widget.onBrowse,
                  )
                else ...[
                  FoodSearchField(
                    controller: _search,
                    hint: 'Search saved meals',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${filtered.length} of ${saved.length} saved ${saved.length == 1 ? 'meal' : 'meals'}',
                    style: const TextStyle(color: FoodWiseColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    BrowseState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching favorites',
                      message: 'Try a different search.',
                      actionLabel: 'Clear search',
                      onAction: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
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
}
