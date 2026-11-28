import 'dart:convert';

/// In-memory cache for child profiles, plans, saved books, and public catalogs.
class LocalDataCache {
  /// Creates a [LocalDataCache] with optional pre-populated [initialCache] data.
  LocalDataCache({Map<String, dynamic>? initialCache})
    : _store = initialCache != null
          ? Map<String, dynamic>.from(initialCache)
          : <String, dynamic>{};

  // Internal storage mapping cache keys to deserialized JSON payloads.
  final Map<String, dynamic> _store;

  // Endpoint prefixes permitted for local offline caching (excludes journal notes).
  static const List<String> _permittedPrefixes = [
    '/api/v1/children',
    '/api/v1/catalog/activities',
    '/api/v1/catalog/milestones',
    '/api/v1/catalog/rhymes',
    '/api/v1/catalog/books',
  ];

  /// Returns whether [path] is permitted for local offline caching.
  bool isCacheablePath(String path) {
    if (path.contains('/plans')) return true;
    if (RegExp(r'^/api/v1/children/[^/]+/books$').hasMatch(path)) {
      return true;
    }
    for (final prefix in _permittedPrefixes) {
      if (path == prefix || path.startsWith('$prefix?')) return true;
    }
    return false;
  }

  /// Generates a normalized cache key from [path] and optional [queryParams].
  String generateKey(String path, [Map<String, String>? queryParams]) {
    if (queryParams == null || queryParams.isEmpty) return path;
    final sortedKeys = queryParams.keys.toList()..sort();
    final query = sortedKeys.map((k) => '$k=${queryParams[k]}').join('&');
    return '$path?$query';
  }

  /// Retrieves a defensive copy of cached data for [key], or `null` if absent.
  dynamic get(String key) {
    final raw = _store[key];
    if (raw == null) return null;
    return jsonDecode(jsonEncode(raw));
  }

  /// Stores [data] under [key] when its endpoint path passes [isCacheablePath].
  void set(String key, dynamic data) {
    final basePath = key.split('?').first;
    if (!isCacheablePath(basePath)) return;
    _store[key] = jsonDecode(jsonEncode(data));
  }

  /// Returns whether cached data exists for [key].
  bool has(String key) => _store.containsKey(key);

  /// Removes any cached entry associated with [key].
  void remove(String key) => _store.remove(key);

  /// Clears all cached entries across the application.
  void clear() => _store.clear();

  /// Clears cached child profiles and plans while keeping public catalog items.
  void clearChildData() {
    _store.removeWhere(
      (key, _) => key.contains('/children') || key.contains('/plans'),
    );
  }

  /// Number of currently cached dataset entries.
  int get entryCount => _store.length;
}
