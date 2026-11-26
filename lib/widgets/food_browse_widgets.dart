import 'package:flutter/material.dart';

import '../foodwise_theme.dart';
import '../models/food.dart';
import '../services/student_food_controller.dart';
import '../screens/food_detail_screen.dart';
import 'favorite_feedback.dart';

/// Center and constrain content on large browser windows.
class FoodWisePage extends StatelessWidget {
  final Widget child;
  const FoodWisePage({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1160),
      child: child,
    ),
  );
}

class BrowseState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const BrowseState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: FoodWiseColors.deepOrange),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: FoodWiseColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FoodWiseColors.muted, height: 1.5),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class FoodSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  const FoodSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FoodWiseColors.border),
      ),
    ),
  );
}

bool matchesFoodSearch(Food food, String query) {
  final q = query.trim().toLowerCase();
  return food.name.toLowerCase().contains(q) ||
      food.categoryName.toLowerCase().contains(q) ||
      food.businessName.toLowerCase().contains(q);
}

class FoodGrid extends StatelessWidget {
  final List<Food> foods;
  final StudentFoodController controller;
  const FoodGrid({super.key, required this.foods, required this.controller});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = scale > 1.5
          ? (width >= 900 ? 2 : 1)
          : (width >= 1000
                ? 4
                : width >= 690
                ? 3
                : width >= 350
                ? 2
                : 1);
      final height = 286.0 + (scale > 1 ? (scale - 1) * 125 : 0);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: foods.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: height,
        ),
        itemBuilder: (context, index) =>
            FoodCard(food: foods[index], controller: controller),
      );
    },
  );
}

class FoodImage extends StatelessWidget {
  final String? url;
  const FoodImage({super.key, this.url});
  Widget _placeholder(IconData icon) => ColoredBox(
    color: FoodWiseColors.paleOrange,
    child: Center(
      child: Icon(icon, color: FoodWiseColors.deepOrange, size: 40),
    ),
  );
  @override
  Widget build(BuildContext context) => url == null || url!.trim().isEmpty
      ? _placeholder(Icons.restaurant_rounded)
      : Image.network(
          url!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) =>
              _placeholder(Icons.image_not_supported_outlined),
        );
}

class FoodCard extends StatelessWidget {
  final Food food;
  final StudentFoodController controller;
  const FoodCard({super.key, required this.food, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      return Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: FoodWiseColors.border),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  FoodDetailScreen(food: food, controller: controller),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 132,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(url: food.imageUrl),
                    if (!food.isAvailable)
                      const ColoredBox(color: Colors.black26),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            food.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: food.isAvailable
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: FavoriteButton(
                          controller: controller,
                          food: food,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FoodWiseColors.deepOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FoodWiseColors.charcoal,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        food.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FoodWiseColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '₱${food.price.toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FoodWiseColors.deepOrange,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                            color: FoodWiseColors.deepOrange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
