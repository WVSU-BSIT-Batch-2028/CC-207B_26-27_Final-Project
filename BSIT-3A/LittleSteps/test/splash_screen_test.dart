import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/screens/auth/sign_in_screen.dart';
import 'package:littlesteps/screens/splash/splash_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return const AuthUser(
      id: 'u1',
      email: 'caregiver@example.com',
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

Widget _buildSplashApp({required AuthSessionState sessionState}) {
  return AuthScope(
    sessionState: sessionState,
    apiClient: ApiClient(baseUrl: 'http://test'),
    child: MaterialApp(
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/sign-in': (_) => const SignInScreen(),
        '/': (_) => const Scaffold(body: Text('Home Shell Screen')),
      },
    ),
  );
}

void main() {
  group('SplashScreen Navigation and Branding', () {
    testWidgets('renders brand emblem and wordmark cleanly', (tester) async {
      final sessionState = AuthSessionState(authService: _FakeAuthService());

      await tester.pumpWidget(_buildSplashApp(sessionState: sessionState));
      expect(find.text('LittleSteps'), findsOneWidget);
      expect(find.text('Small steps. Brighter tomorrows.'), findsOneWidget);

      // Settle timer and transition
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      // Navigates unauthenticated user to sign in
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('navigates authenticated caregiver to home shell', (
      tester,
    ) async {
      final sessionState = AuthSessionState(authService: _FakeAuthService());
      await sessionState.signIn(
        email: 'caregiver@example.com',
        password: 'password123',
      );

      await tester.pumpWidget(_buildSplashApp(sessionState: sessionState));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.text('Home Shell Screen'), findsOneWidget);
    });

    testWidgets(
      'respects disableAnimations and renders without overflow at 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sessionState = AuthSessionState(authService: _FakeAuthService());

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              disableAnimations: true,
              textScaler: TextScaler.linear(2.0),
            ),
            child: _buildSplashApp(sessionState: sessionState),
          ),
        );

        expect(find.text('LittleSteps'), findsOneWidget);
        expect(find.text('Small steps. Brighter tomorrows.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle(const Duration(milliseconds: 600));
        expect(find.byType(SignInScreen), findsOneWidget);
      },
    );
  });
}
