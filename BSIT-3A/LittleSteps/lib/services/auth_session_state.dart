import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../models/child.dart';
import '../models/weather.dart';
import 'auth_service.dart';

/// Manages the in-memory authentication session and active child profile.
///
/// Coordinates user authentication status and the currently selected child profile
/// across the application without persisting credentials in plaintext storage.
class AuthSessionState extends ChangeNotifier {
  /// Creates an [AuthSessionState] with the provided [authService] and optional [onClearCache].
  AuthSessionState({required this.authService, this.onClearCache});

  /// The underlying authentication service.
  final AuthService authService;

  /// Optional callback invoked on sign-out or session expiry to clear local caches.
  final VoidCallback? onClearCache;

  AuthUser? _currentUser;
  Child? _activeChild;
  String? _unsavedDraft;
  WeatherLocation? _weatherLocation = WeatherLocation.iloiloCity;

  /// Currently signed-in caregiver user, or `null` if unauthenticated.
  AuthUser? get currentUser => _currentUser;

  /// Whether a caregiver is currently signed in.
  bool get isAuthenticated => _currentUser != null;

  /// Currently selected active child profile, or `null` if none selected.
  Child? get activeChild => _activeChild;

  /// Any unsaved draft text preserved across session expirations.
  String? get unsavedDraft => _unsavedDraft;

  /// Selected Philippine city for optional Open-Meteo play-weather hints,
  /// or `null` when weather hints are turned off.
  WeatherLocation? get weatherLocation => _weatherLocation;

  /// Active ID token for API authorization.
  String? get idToken => _currentUser?.idToken;

  /// Updates the city used for optional play-weather hints.
  ///
  /// Pass `null` to disable weather hints across the app.
  void setWeatherLocation(WeatherLocation? location) {
    if (_weatherLocation == location) return;
    _weatherLocation = location;
    notifyListeners();
  }

  /// Updates or preserves an unsaved draft before signing out or upon expiry.
  void setUnsavedDraft(String? draft) {
    _unsavedDraft = draft;
    notifyListeners();
  }

  /// Clears any preserved unsaved draft.
  void clearUnsavedDraft() {
    _unsavedDraft = null;
    notifyListeners();
  }

  /// Sets the currently active child profile.
  void setActiveChild(Child? child) {
    _activeChild = child;
    notifyListeners();
  }

  /// Signs in a caregiver using [email] and [password].
  Future<void> signIn({required String email, required String password}) async {
    final user = await authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    _currentUser = user;
    notifyListeners();
  }

  /// Creates a new caregiver account with [email] and [password].
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    final user = await authService.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );
    _currentUser = user;
    notifyListeners();
  }

  /// Refreshes the active ID token using the saved refresh token.
  Future<String?> refreshToken() async {
    final token = _currentUser?.refreshToken;
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final refreshed = await authService.refreshToken(token);
      _currentUser = _currentUser?.copyWith(
        idToken: refreshed.idToken,
        refreshToken: refreshed.refreshToken ?? token,
        expiresAt: refreshed.expiresAt,
      );
      notifyListeners();
      return _currentUser?.idToken;
    } catch (_) {
      return null;
    }
  }

  /// Handles unrecoverable session expiry: signs out and clears child data
  /// while preserving any unsaved drafts.
  void handleSessionExpired() {
    _currentUser = null;
    _activeChild = null;
    onClearCache?.call();
    notifyListeners();
  }

  /// Signs out the caregiver and clears all cached child data.
  Future<void> signOut() async {
    try {
      await authService.signOut();
    } finally {
      _currentUser = null;
      _activeChild = null;
      _unsavedDraft = null;
      onClearCache?.call();
      notifyListeners();
    }
  }
}
