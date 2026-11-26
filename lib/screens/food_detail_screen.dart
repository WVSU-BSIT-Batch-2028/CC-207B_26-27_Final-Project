import 'package:flutter/material.dart';

import '../foodwise_theme.dart';
import '../models/food.dart';
import '../services/student_food_controller.dart';
import '../widgets/favorite_feedback.dart';

class FoodDetailScreen extends StatelessWidget {
  final Food food;
  final StudentFoodController controller;

  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodWiseColors.background,
      appBar: AppBar(
        backgroundColor: FoodWiseColors.background,
        foregroundColor: FoodWiseColors.charcoal,
        elevation: 0,
        title: const Text(
          'Food Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) =>
                FavoriteButton(controller: controller, food: food),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 290,
                width: double.infinity,
                child: food.imageUrl == null || food.imageUrl!.isEmpty
                    ? Container(
                        color: FoodWiseColors.lightOrange,
                        child: const Icon(
                          Icons.restaurant_rounded,
                          size: 85,
                          color: FoodWiseColors.orange,
                        ),
                      )
                    : Image.network(
                        food.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: FoodWiseColors.lightOrange,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 65,
                              color: FoodWiseColors.orange,
                            ),
                          );
                        },
                      ),
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
                  decoration: const BoxDecoration(
                    color: FoodWiseColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: FoodWiseColors.lightOrange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          food.categoryName.toUpperCase(),
                          style: const TextStyle(
                            color: FoodWiseColors.deepOrange,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        food.name,
                        style: const TextStyle(
                          color: FoodWiseColors.charcoal,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₱${food.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: FoodWiseColors.orange,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _detailHeading('Description'),
                      const SizedBox(height: 8),
                      Text(
                        food.description.isEmpty
                            ? 'No description available.'
                            : food.description,
                        style: const TextStyle(
                          color: FoodWiseColors.muted,
                          height: 1.6,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 23),
                      _detailHeading('Food Provider'),
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FoodWiseColors.border),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: FoodWiseColors.paleOrange,
                              child: Icon(
                                Icons.storefront_rounded,
                                color: FoodWiseColors.deepOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    food.businessName,
                                    style: const TextStyle(
                                      color: FoodWiseColors.charcoal,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (food.businessAddress.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      food.businessAddress,
                                      style: const TextStyle(
                                        color: FoodWiseColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FoodWiseColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: FoodWiseColors.orange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                food.caloriesKcal == null
                                    ? 'Calories: Not available'
                                    : 'Calories: ${food.caloriesKcal!.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                  color: FoodWiseColors.charcoal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 17),
                      Row(
                        children: [
                          Icon(
                            food.isAvailable
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: food.isAvailable ? Colors.green : Colors.red,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            food.isAvailable
                                ? 'Currently available'
                                : 'Currently unavailable',
                            style: TextStyle(
                              color: food.isAvailable
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w800,
                            ),
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
      ),
    );
  }

  Widget _detailHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: FoodWiseColors.charcoal,
        fontWeight: FontWeight.w900,
        fontSize: 17,
      ),
    );
  }
}
