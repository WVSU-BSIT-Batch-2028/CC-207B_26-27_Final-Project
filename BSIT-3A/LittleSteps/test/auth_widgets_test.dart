import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/main.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/auth/register_screen.dart';
import 'package:littlesteps/screens/auth/sign_in_screen.dart';
import 'package:littlesteps/screens/auth/signed_out_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

class FakeAuthService implements AuthService {
  bool shouldFail = false;
  AuthUser? loggedInUser;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldFail) {
      throw const AuthException(
        code: 'auth/invalid-credential',
        message: "That email and password don't match an account. Please check them and try again.",
      );
    }
    final user = AuthUser(
      id: 'demo-123',
      email: email,
      idToken: 'demo-id-token',
      refreshToken: 'demo-refresh',
    );
    loggedInUser = user;
    return user;
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: 'registered-123',
      email: email,
      idToken: 'reg-token',
      refreshToken: 'reg-refresh',
    );
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    return AuthUser(
      id: 'demo-123',
      email: 'littlesteps@demo.com',
      idToken: 'refreshed-token',
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> signOut() async {
    loggedInUser = null;
  }
}

Widget createTestApp({
  required AuthSessionState sessionState,
  ApiClient? apiClient,
  Widget? home,
}) {
  final client = apiClient ?? ApiClient(baseUrl: 'http://test-api');
  return AuthScope(
    sessionState: sessionState,
    apiClient: client,
    child: MaterialApp(
      home:
          home ?? LittleStepsApp(sessionState: sessionState, apiClient: client),
      routes: {
        '/sign-in': (_) => const SignInScreen(),
        '/register': (_) => const RegisterScreen(),
        '/signed-out': (_) => const SignedOutScreen(),
      },
    ),
  );
}

void main() {
  group('Auth & Protected Shell Widgets', () {
    late FakeAuthService fakeAuthService;
    late AuthSessionState sessionState;

    setUp(() {
      fakeAuthService = FakeAuthService();
      sessionState = AuthSessionState(authService: fakeAuthService);
    });

    testWidgets('unauthenticated state redirects to sign in screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(sessionState: sessionState, home: const LittleStepsApp()),
      );
      await tester.pumpAndSettle();

      // Gated directly to SignInScreen to enforce authentication before exploring
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Sign in to your caregiver account'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets(
      'signed-in state displays active child profile in shell header',
      (tester) async {
        await sessionState.signIn(
          email: 'littlesteps@demo.com',
          password: 'password123',
        );
        sessionState.setActiveChild(
          Child(
            id: 'c1',
            nickname: 'Liam',
            ageBand: '48m',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );

        await tester.pumpWidget(
          LittleStepsApp(
            sessionState: sessionState,
            apiClient: ApiClient(baseUrl: 'http://test-api'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Liam (48m)'), findsOneWidget);
      },
    );

    testWidgets(
      'SignInScreen fits compact mobile viewport without scrolling and toggles password',
      (tester) async {
        tester.view.physicalSize = const Size(393 * 2, 852 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestApp(sessionState: sessionState, home: const SignInScreen()),
        );
        await tester.pumpAndSettle();

        // Focused header with tagline, single primary CTA, and lightweight account footer
        expect(find.text('LittleSteps'), findsOneWidget);
        expect(find.text('Small steps. Brighter tomorrows.'), findsOneWidget);
        expect(find.text('Sign in to your caregiver account'), findsOneWidget);
        expect(find.text('New to LittleSteps?'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget);
        expect(find.text('Welcome back'), findsNothing);

        // Fits within a standard mobile viewport with no scroll extent
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scrollable.position.maxScrollExtent, 0.0);

        // Password visibility toggle
        final passwordFieldFinder = find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(TextField),
        );
        final passwordWidget = tester.widget<TextField>(passwordFieldFinder);
        expect(passwordWidget.obscureText, isTrue);

        // Tap toggle icon
        final toggleFinder = find.bySemanticsLabel('Show password');
        expect(toggleFinder, findsOneWidget);
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        final updatedPasswordWidget = tester.widget<TextField>(
          passwordFieldFinder,
        );
        expect(updatedPasswordWidget.obscureText, isFalse);
      },
    );

    testWidgets(
      'SignInScreen displays calm error message on failed authentication',
      (tester) async {
        fakeAuthService.shouldFail = true;

        await tester.pumpWidget(
          createTestApp(sessionState: sessionState, home: const SignInScreen()),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'wrong@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'badpassword',
        );

        final signInButton = find.widgetWithText(FilledButton, 'Sign in');
        await tester.ensureVisible(signInButton);
        await tester.tap(signInButton);
        await tester.pumpAndSettle();

        expect(
          find.text(
            "That email and password don't match an account. Please check them and try again.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RegisterScreen displays privacy notice before account creation and enforces acceptance',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            sessionState: sessionState,
            home: const RegisterScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Privacy Notice points are visible
        expect(find.text('Privacy Notice'), findsOneWidget);
        expect(find.text('What we collect'), findsOneWidget);
        expect(find.text('Who sees it'), findsOneWidget);
        expect(
          find.text(
            'Only you. Notes never go to external AI, analytics, or error logs.',
          ),
          findsOneWidget,
        );

        // Filling email and password without checking privacy box is blocked
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'caregiver@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'securepassword123',
        );

        final createBtnFinder = find.widgetWithText(
          FilledButton,
          'Create account',
        );
        await tester.ensureVisible(createBtnFinder);
        await tester.tap(createBtnFinder);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Please read and accept the privacy notice before creating an account.',
          ),
          findsOneWidget,
        );

        // Checking privacy notice unblocks creation
        final checkbox = find.byType(Checkbox);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        await tester.ensureVisible(createBtnFinder);
        await tester.tap(createBtnFinder);
        await tester.pumpAndSettle();

        expect(sessionState.isAuthenticated, isTrue);
      },
    );

    testWidgets('SignedOutScreen shows message and preserves unsaved draft', (
      tester,
    ) async {
      sessionState.setUnsavedDraft(
        'Observed Maya stacking 4 blocks on the floor.',
      );

      await tester.pumpWidget(
        createTestApp(
          sessionState: sessionState,
          home: const SignedOutScreen(
            message: 'Please sign in again to continue',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please sign in again to continue'), findsOneWidget);
      expect(find.text('Your unsaved draft is safe'), findsOneWidget);
      expect(
        find.text('Observed Maya stacking 4 blocks on the floor.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'SignInScreen renders cleanly without overflow at 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(375 * 2, 667 * 2);
        tester.view.devicePixelRatio = 2.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 667),
              textScaler: TextScaler.linear(2.0),
            ),
            child: createTestApp(
              sessionState: sessionState,
              home: const SignInScreen(
                notice: 'Please sign in again to continue',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify that SignInScreen renders without throwing any FlutterError or overflow
        expect(find.text('Sign in'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SignInScreen switches to two-pane split layout on wide desktop viewports',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestApp(sessionState: sessionState, home: const SignInScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('LittleSteps'), findsOneWidget);
        expect(find.text('Small steps. Brighter tomorrows.'), findsOneWidget);
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('Plan play and note what you can.'), findsOneWidget);
        expect(find.text('Sign in to your caregiver account'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RegisterScreen uses two-pane layout on wide viewports and clean helper copy',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestApp(
            sessionState: sessionState,
            home: const RegisterScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create your account'), findsOneWidget);
        expect(find.text('At least 8 characters'), findsOneWidget);
        expect(find.textContaining('Password managers'), findsNothing);
        expect(find.text('Already have an account?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RegisterScreen renders cleanly without overflow at 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(375 * 2, 667 * 2);
        tester.view.devicePixelRatio = 2.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 667),
              textScaler: TextScaler.linear(2.0),
            ),
            child: createTestApp(
              sessionState: sessionState,
              home: const RegisterScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create an account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
