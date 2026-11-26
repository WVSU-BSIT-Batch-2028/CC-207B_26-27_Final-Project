import 'package:flutter/material.dart';

import '../foodwise_theme.dart';
import '../services/auth_service.dart';
import '../services/student_food_controller.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'ai_assistant_screen.dart';
import 'spin_meal_screen.dart';
import 'profile_screen.dart';

class StudentNavigationScreen extends StatefulWidget {
  const StudentNavigationScreen({super.key});

  @override
  State<StudentNavigationScreen> createState() =>
      _StudentNavigationScreenState();
}

class _StudentNavigationScreenState extends State<StudentNavigationScreen> {
  static const int _homeIndex = 0;
  static const int _aiIndex = 2;
  static const int _profileIndex = 4;

  late final StudentFoodController _food;
  late Future<Map<String, dynamic>?> _profileFuture;
  int _selectedIndex = _homeIndex;
  bool _hasOpenedAi = false;

  @override
  void initState() {
    super.initState();
    _food = StudentFoodController();
    _profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() async =>
      AuthService.getProfile();

  void _refreshProfile() {
    if (!mounted) {
      return;
    }
    setState(() => _profileFuture = _loadProfile());
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      if (index == _aiIndex) {
        _hasOpenedAi = true;
      }
      if (index == _profileIndex) {
        _profileFuture = _loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _food.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodWiseColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _BrandHeader(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  HomeScreen(controller: _food, profileFuture: _profileFuture),
                  FavoritesScreen(
                    controller: _food,
                    onBrowse: () => _selectTab(_homeIndex),
                  ),
                  if (_hasOpenedAi)
                    AiAssistantScreen(
                      embedded: true,
                      isActive: _selectedIndex == _aiIndex,
                    )
                  else
                    const SizedBox.shrink(),
                  const SpinMealScreen(),
                  ProfileScreen(
                    profileFuture: _profileFuture,
                    onRefresh: _refreshProfile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _FoodWiseBottomBar(
        selectedIndex: _selectedIndex,
        onSelected: _selectTab,
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: FoodWiseColors.orange,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FoodWise',
                style: TextStyle(
                  color: FoodWiseColors.charcoal,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'GOOD FOOD, SMART CHOICES',
                style: TextStyle(
                  color: FoodWiseColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The AI Assistant remains visually prominent even when another tab is active.
class _FoodWiseBottomBar extends StatelessWidget {
  const _FoodWiseBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FoodWiseColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _item(0, 'Home', Icons.home_outlined, Icons.home_rounded),
                _item(
                  1,
                  'Favorites',
                  Icons.favorite_border_rounded,
                  Icons.favorite_rounded,
                ),
                _item(
                  2,
                  'AI Assistant',
                  Icons.auto_awesome_rounded,
                  Icons.auto_awesome_rounded,
                  featured: true,
                ),
                _item(
                  3,
                  'Spin Meal',
                  Icons.casino_outlined,
                  Icons.casino_rounded,
                ),
                _item(
                  4,
                  'Profile',
                  Icons.person_outline_rounded,
                  Icons.person_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    int index,
    String label,
    IconData icon,
    IconData selectedIcon, {
    bool featured = false,
  }) {
    final selected = selectedIndex == index;
    final color = selected || featured
        ? FoodWiseColors.deepOrange
        : FoodWiseColors.muted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 54,
                  child: Center(
                    child: featured
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected
                                  ? FoodWiseColors.deepOrange
                                  : FoodWiseColors.orange,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 29,
                            ),
                          )
                        : Icon(
                            selected ? selectedIcon : icon,
                            color: color,
                            size: 25,
                          ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected || featured
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                // A separate marker distinguishes the active tab from the
                // permanently highlighted AI shortcut.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 15,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
