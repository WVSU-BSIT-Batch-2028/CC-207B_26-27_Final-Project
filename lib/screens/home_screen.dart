import 'package:flutter/material.dart';

import '../models/food.dart';
import '../services/auth_service.dart';
import '../services/strapi_service.dart';
import 'welcome_screen.dart';

// ============================================================
// FOODWISE THEME COLORS
// Keep these colors consistent with foodwise_theme.dart.
// ============================================================
const Color orange = Color(0xFFE96B10);
const Color deepOrange = Color(0xFFD95708);
const Color lightOrange = Color(0xFFFFE7D1);
const Color paleOrange = Color(0xFFFFF1E5);
const Color cream = Color(0xFFFFF8F1);
const Color charcoal = Color(0xFF30251F);
const Color muted = Color(0xFF88786E);
const Color borderColor = Color(0xFFF0DFD2);

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  // Food items are loaded from the Strapi CMS.
  late Future<List<Food>> foodFuture;

  // Student profile is loaded from Supabase.
  late Future<Map<String, dynamic>?> profileFuture;

  final TextEditingController searchController = TextEditingController();

  // Favorites are kept while the app is running.
  // TODO: Connect favorites to Supabase if persistent saving is required.
  final Set<String> favoriteIds = {};

  int selectedTab = 0;
  String selectedCategory = 'All';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    foodFuture = StrapiService.fetchFoodItems();
    profileFuture = AuthService.getProfile();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String foodKey(Food food) {
    return food.documentId.isNotEmpty
        ? food.documentId
        : food.id.toString();
  }

  Future<void> refreshFood() async {
    final newFuture = StrapiService.fetchFoodItems();
    setState(() {
      foodFuture = newFuture;
    });
    await newFuture;
  }

  // ============================================================
  // AUTHENTICATION: SIGN OUT
  // Keep this connected to the existing Supabase AuthService.
  // ============================================================
  Future<void> logout() async {
    try {
      await AuthService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to sign out: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Sign Out?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: charcoal,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out of your FoodWise account?',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: muted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await logout();
    }
  }

  // ============================================================
  // FAVORITES AND FOOD FILTERING
  // ============================================================
  void toggleFavorite(Food food) {
    final key = foodKey(food);

    setState(() {
      if (favoriteIds.contains(key)) {
        favoriteIds.remove(key);
      } else {
        favoriteIds.add(key);
      }
    });
  }

  List<String> getCategories(List<Food> foods) {
    final categories = foods
        .map((food) => food.categoryName)
        .toSet()
        .toList()
      ..sort();

    return ['All', ...categories];
  }

  List<Food> filterFoods(List<Food> foods) {
    return foods.where((food) {
      final matchesCategory = selectedCategory == 'All' ||
          food.categoryName == selectedCategory;

      final query = searchQuery.toLowerCase().trim();

      final matchesSearch = food.name.toLowerCase().contains(query) ||
          food.categoryName.toLowerCase().contains(query) ||
          food.businessName.toLowerCase().contains(query);

      final matchesFavorite =
          selectedTab != 1 || favoriteIds.contains(foodKey(food));

      return matchesCategory && matchesSearch && matchesFavorite;
    }).toList();
  }

  void openFoodDetails(Food food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: food,
          isFavorite: favoriteIds.contains(foodKey(food)),
          onFavoritePressed: () => toggleFavorite(food),
        ),
      ),
    ).then((_) {
      // Refresh the favorite icon when returning from the detail page.
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: FutureBuilder<List<Food>>(
                future: foodFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: orange),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final foods = snapshot.data ?? [];

                  if (foods.isEmpty) {
                    return _buildEmptyState(
                      'No food items available yet.',
                    );
                  }

                  // The profile tab has its own Supabase FutureBuilder.
                  if (selectedTab == 2) {
                    return _buildProfilePage();
                  }

                  return _buildContent(foods);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [orange, Color(0xFFFFA64D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FoodWise',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: charcoal,
                  letterSpacing: -0.7,
                ),
              ),
              Text(
                'GOOD FOOD, SMART CHOICES',
                style: TextStyle(
                  fontSize: 8,
                  color: muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: confirmLogout,
            tooltip: 'Sign Out',
            style: IconButton.styleFrom(
              backgroundColor: paleOrange,
              foregroundColor: orange,
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOME AND FAVORITES CONTENT
  // ============================================================
  Widget _buildContent(List<Food> foods) {
    final categories = getCategories(foods);
    final filteredFoods = filterFoods(foods);

    return RefreshIndicator(
      color: orange,
      onRefresh: refreshFood,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (selectedTab == 0) ...[
            _buildWelcomeSection(),
            const SizedBox(height: 22),
          ] else ...[
            _buildFavoritesHeader(),
            const SizedBox(height: 20),
          ],
          _buildSearchBar(),
          const SizedBox(height: 25),
          if (selectedTab == 0) ...[
            _buildSectionHeading(
              'Find your cravings',
              'Choose a category to explore',
            ),
            const SizedBox(height: 13),
            _buildCategoryList(categories),
            const SizedBox(height: 25),
            _buildSectionHeading(
              'Popular on campus',
              '${filteredFoods.length} food items',
            ),
          ] else ...[
            _buildSectionHeading(
              'Your saved meals',
              '${filteredFoods.length} favorite items',
            ),
          ],
          const SizedBox(height: 14),
          if (filteredFoods.isEmpty)
            _buildEmptyState(
              selectedTab == 1
                  ? 'No favorites yet. Tap the heart on a food card to save it.'
                  : 'No matching food items found.',
            )
          else
            _buildFoodGrid(filteredFoods),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: profileFuture,
      builder: (context, snapshot) {
        final fullName =
            snapshot.data?['full_name']?.toString() ?? 'Student';
        final firstName = fullName.trim().isEmpty
            ? 'Student'
            : fullName.trim().split(' ').first;

        return Container(
          height: 205,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [deepOrange, orange, Color(0xFFFFA64D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: orange.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -28,
                child: Icon(
                  Icons.ramen_dining_rounded,
                  size: 160,
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),
              Positioned(
                right: 20,
                top: 8,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.19),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'YOUR CAMPUS FOOD GUIDE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'Hey, $firstName! 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const SizedBox(
                    width: 235,
                    child: Text(
                      'Hungry? Discover delicious and affordable meals around your campus.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CAMPUS FOOD DIRECTORY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: paleOrange,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: lightOrange),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            child: Icon(Icons.favorite_rounded, color: orange, size: 25),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Favorites',
                  style: TextStyle(
                    color: charcoal,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'All the meals you love in one place.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Search matches food name, category, and food provider.
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: charcoal.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'What are you craving today?',
          hintStyle: const TextStyle(color: muted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: orange,
            size: 23,
          ),
          suffixIcon: searchQuery.isEmpty
              ? const Icon(Icons.tune_rounded, color: muted, size: 20)
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded, color: muted),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: orange, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: charcoal,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.restaurant_rounded,
          color: orange,
          size: 20,
        ),
      ],
    );
  }

  // Category filters are generated from the categories in Strapi.
  Widget _buildCategoryList(List<String> categories) {
    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;

          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                selectedCategory = category;
              });
            },
            selectedColor: orange,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            side: BorderSide(
              color: isSelected ? orange : borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          );
        },
      ),
    );
  }

  // Responsive grid: two columns on phones and three on wider screens.
  Widget _buildFoodGrid(List<Food> foods) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: foods.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 2 ? 0.66 : 0.78,
          ),
          itemBuilder: (context, index) {
            return _buildFoodCard(foods[index]);
          },
        );
      },
    );
  }

  // Individual food card. Tapping the card opens its detail page.
  Widget _buildFoodCard(Food food) {
    final isFavorite = favoriteIds.contains(foodKey(food));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openFoodDetails(food),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: charcoal.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _foodImage(food.imageUrl),
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          food.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: food.isAvailable
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onPressed: () => toggleFavorite(food),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite ? orange : charcoal,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                    if (!food.isAvailable)
                      Container(
                        color: Colors.black38,
                        alignment: Alignment.center,
                        child: const Text(
                          'NOT AVAILABLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.categoryName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: orange,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: charcoal,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '₱${food.price.toStringAsFixed(2)}',
                              maxLines: 1,
                              style: const TextStyle(
                                color: orange,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                              color: paleOrange,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: orange,
                              size: 17,
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

  // Loads the image URL returned by Strapi.
  // If an item has no image or the URL fails, show a placeholder.
  Widget _foodImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: lightOrange,
        child: const Center(
          child: Icon(
            Icons.restaurant_rounded,
            color: orange,
            size: 45,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: lightOrange,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: orange,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PROFILE PAGE
  // Profile information continues to come from Supabase.
  // ============================================================
  Widget _buildProfilePage() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: orange),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildEmptyState('Unable to load your student profile.');
        }

        final profile = snapshot.data!;
        final fullName = profile['full_name']?.toString() ?? 'Student';
        final role = profile['role']?.toString() ?? 'student';

        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, paleOrange],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: lightOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 43,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person_rounded,
                        color: orange,
                        size: 53,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: charcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lightOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: deepOrange,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    color: orange,
                    size: 23,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Welcome to your FoodWise student account!',
                      style: TextStyle(
                        color: charcoal,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: confirmLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOADING, ERROR, AND EMPTY STATES
  // ============================================================
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: orange,
              size: 55,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load food items',
              style: TextStyle(
                color: charcoal,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                setState(() {
                  foodFuture = StrapiService.fetchFoodItems();
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: paleOrange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: orange,
              size: 42,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: charcoal.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) {
          setState(() {
            selectedTab = index;
            selectedCategory = 'All';
            searchQuery = '';
            searchController.clear();
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: orange,
        unselectedItemColor: muted,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FOOD DETAIL SCREEN
// Kept in this file so no additional route or file is required.
// ============================================================
class FoodDetailScreen extends StatelessWidget {
  final Food food;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.isFavorite,
    required this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        foregroundColor: charcoal,
        elevation: 0,
        title: const Text(
          'Food Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed: onFavoritePressed,
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: orange,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 290,
            width: double.infinity,
            child: food.imageUrl == null || food.imageUrl!.isEmpty
                ? Container(
                    color: lightOrange,
                    child: const Icon(
                      Icons.restaurant_rounded,
                      size: 85,
                      color: orange,
                    ),
                  )
                : Image.network(
                    food.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: lightOrange,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 65,
                          color: orange,
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
                color: cream,
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
                      color: lightOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      food.categoryName.toUpperCase(),
                      style: const TextStyle(
                        color: deepOrange,
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
                      color: charcoal,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₱${food.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: orange,
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
                      color: muted,
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
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: paleOrange,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: orange,
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
                                  color: charcoal,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (food.businessAddress.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  food.businessAddress,
                                  style: const TextStyle(
                                    color: muted,
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
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            food.caloriesKcal == null
                                ? 'Calories: Not available'
                                : 'Calories: ${food.caloriesKcal!.toStringAsFixed(0)} kcal',
                            style: const TextStyle(
                              color: charcoal,
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
    );
  }

  Widget _detailHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: charcoal,
        fontWeight: FontWeight.w900,
        fontSize: 17,
      ),
    );
  }
}
