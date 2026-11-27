import 'package:flutter/material.dart';

import '../models/food.dart';
import 'favorites_service.dart';
import 'strapi_service.dart';

/// One controller per signed-in student's navigation shell.
class StudentFoodController extends ChangeNotifier {
  StudentFoodController() {
    foodFuture = _fetch();
    loadFavorites();
  }

  late Future<List<Food>> foodFuture;
  final FavoritesService _service = FavoritesService();
  final Set<String> _favorites = {};
  final Set<String> _pending = {};
  bool _disposed = false;
  bool favoritesLoading = false;
  bool favoritesFailed = false;
  bool favoritesReady = false;
  bool get active => !_disposed;

  Future<List<Food>> _fetch() async => StrapiService.fetchFoodItems();

  String foodKey(Food food) => food.documentId.trim();
  bool hasDocumentId(Food food) => foodKey(food).isNotEmpty;
  bool isFavorite(Food food) =>
      hasDocumentId(food) && _favorites.contains(foodKey(food));
  bool favoritePending(Food food) => _pending.contains(foodKey(food));
  bool canChangeFavorite(Food food) =>
      active &&
      hasDocumentId(food) &&
      favoritesReady &&
      !favoritesLoading &&
      !favoritesFailed &&
      !favoritePending(food);

  Future<void> loadFavorites() async {
    if (_disposed || favoritesLoading || _pending.isNotEmpty) return;
    favoritesLoading = true;
    favoritesFailed = false;
    notifyListeners();
    try {
      final keys = await _service.fetchFavorites();
      if (_disposed) return;
      _favorites
        ..clear()
        ..addAll(keys);
      favoritesReady = true;
    } catch (_) {
      favoritesFailed = true;
    } finally {
      favoritesLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Update the UI only when Supabase confirms the write.
  /// Returns false if nothing was changed; throws on a failed write.
  Future<bool> setFavorite(Food food, bool saved) async {
    if (!canChangeFavorite(food) || isFavorite(food) == saved) return false;
    final key = foodKey(food);
    _pending.add(key);
    notifyListeners();
    try {
      await _service.setFavorite(key, saved);
      if (_disposed) return false;
      if (saved) {
        _favorites.add(key);
      } else {
        _favorites.remove(key);
      }
      return true;
    } finally {
      _pending.remove(key);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    foodFuture = _fetch();
    notifyListeners();
    final favorites = loadFavorites();
    try {
      await foodFuture;
    } catch (_) {
      // The browse screens show the food loading error.
    }
    await favorites;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
