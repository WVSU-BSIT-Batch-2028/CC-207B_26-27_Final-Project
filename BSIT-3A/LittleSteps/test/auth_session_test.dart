import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';

class MockAuthService implements AuthService {
  AuthUser? mockUser;
  bool signedOut = false;
  String? lastRefreshedToken;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return mockUser ??
        AuthUser(
          id: 'u1',
          email: email,
          idToken: 'token123',
          refreshToken: 'refresh123',
        );
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: 'u2',
      email: email,
      idToken: 'newtoken123',
      refreshToken: 'newrefresh123',
    );
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    lastRefreshedToken = refreshToken;
    return const AuthUser(
      id: 'u1',
      email: 'caregiver@example.com',
      idToken: 'refreshed-id-token',
      refreshToken: 'new-refresh-token',
    );
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  group('AuthSessionState Session Management', () {
    late MockAuthService authService;
    late AuthSessionState sessionState;

    setUp(() {
      authService = MockAuthService();
      sessionState = AuthSessionState(authService: authService);
    });

    test('starts unauthenticated with no active child', () {
      expect(sessionState.isAuthenticated, isFalse);
      expect(sessionState.currentUser, isNull);
      expect(sessionState.activeChild, isNull);
      expect(sessionState.idToken, isNull);
    });

    test('updates state and token when signed in', () async {
      await sessionState.signIn(
        email: 'littlesteps@demo.com',
        password: 'password123',
      );

      expect(sessionState.isAuthenticated, isTrue);
      expect(sessionState.currentUser?.email, 'littlesteps@demo.com');
      expect(sessionState.idToken, 'token123');
    });

    test('clears child data and session upon sign out', () async {
      await sessionState.signIn(
        email: 'caregiver@example.com',
        password: 'pass',
      );
      sessionState.setActiveChild(
        Child(
          id: 'c1',
          nickname: 'Maya',
          ageBand: '12-23m',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      expect(sessionState.activeChild?.nickname, 'Maya');

      await sessionState.signOut();

      expect(sessionState.isAuthenticated, isFalse);
      expect(sessionState.currentUser, isNull);
      expect(sessionState.activeChild, isNull); // Child data is cleared!
      expect(authService.signedOut, isTrue);
    });

    test('preserves unsaved drafts when session expires', () {
      sessionState.setActiveChild(
        Child(
          id: 'c1',
          nickname: 'Maya',
          ageBand: '12-23m',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      sessionState.setUnsavedDraft(
        'My unsaved observation notes about walking.',
      );

      sessionState.handleSessionExpired();

      expect(sessionState.isAuthenticated, isFalse);
      expect(sessionState.activeChild, isNull);
      // Draft remains preserved!
      expect(
        sessionState.unsavedDraft,
        'My unsaved observation notes about walking.',
      );

      sessionState.clearUnsavedDraft();
      expect(sessionState.unsavedDraft, isNull);
    });

    test('refreshes ID token and updates current user', () async {
      await sessionState.signIn(
        email: 'caregiver@example.com',
        password: 'pass',
      );
      final newToken = await sessionState.refreshToken();

      expect(newToken, 'refreshed-id-token');
      expect(sessionState.idToken, 'refreshed-id-token');
      expect(authService.lastRefreshedToken, 'refresh123');
    });
  });
}
