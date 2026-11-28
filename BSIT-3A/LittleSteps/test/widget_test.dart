import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/explore/explore_screen.dart';
import 'package:littlesteps/screens/shell_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/theme/app_theme.dart';
import 'package:littlesteps/widgets/auth_scope.dart';
import 'package:littlesteps/widgets/brand_logo.dart';
import 'package:littlesteps/widgets/child_chip.dart';
import 'package:littlesteps/widgets/no_children_view.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: 'test-user',
      email: email,
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: 'test-user',
      email: email,
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    return AuthUser(
      id: 'test-user',
      email: 'test@example.com',
      idToken: 'token',
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('shell header fits a 320dp viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionState = AuthSessionState(authService: _FakeAuthService());
    await sessionState.signIn(
      email: 'caregiver@example.com',
      password: 'password123',
    );
    final child = Child(
      id: 'child-320',
      nickname: 'Maya',
      ageBand: '12-23m',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    sessionState.setActiveChild(child);

    await tester.pumpWidget(
      AuthScope(
        sessionState: sessionState,
        apiClient: ApiClient(baseUrl: 'http://test'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ShellScreen(children: [child]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(of: find.byType(ChildChip), matching: find.text('Maya')),
      findsOneWidget,
    );
  });

  testWidgets('shell shows five tabs and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ShellScreen()),
    );

    final nav = find.byType(NavigationBar);
    for (final label in [
      'Today',
      'Explore',
      'Milestones',
      'Journal',
      'This week',
    ]) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.descendant(of: nav, matching: find.text('Explore')));
    await tester.pumpAndSettle();
    expect(
      find.text('Simple ideas with things you already have.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shell shows NoChildrenView across tabs when caregiver has no active child',
    (tester) async {
      final sessionState = AuthSessionState(authService: _FakeAuthService());
      await sessionState.signIn(
        email: 'lovelly@example.com',
        password: 'password123',
      );

      await tester.pumpWidget(
        AuthScope(
          sessionState: sessionState,
          apiClient: ApiClient(baseUrl: 'http://test'),
          child: const MaterialApp(home: ShellScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Child selector chip is omitted when no child profile exists
      expect(find.byType(ChildChip), findsNothing);

      // Today tab displays NoChildrenView onboarding
      expect(find.byType(NoChildrenView), findsOneWidget);
      expect(find.text('Welcome, Lovelly'), findsOneWidget);
      expect(
        find.text("Let's set up your first child profile."),
        findsOneWidget,
      );
      expect(find.text('No children added yet'), findsOneWidget);
      expect(find.text('Add a child'), findsOneWidget);

      final nav = find.byType(NavigationBar);

      // Explore tab also displays NoChildrenView onboarding
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Explore')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No children added yet'), findsOneWidget);

      // Milestones tab displays NoChildrenView onboarding
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Milestones')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No children added yet'), findsOneWidget);

      // This week tab displays NoChildrenView onboarding
      await tester.tap(
        find.descendant(of: nav, matching: find.text('This week')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No children added yet'), findsOneWidget);
    },
  );

  testWidgets(
    'shell displays child chip and populated screens when active child is present',
    (tester) async {
      final sessionState = AuthSessionState(authService: _FakeAuthService());
      await sessionState.signIn(
        email: 'caregiver@example.com',
        password: 'password123',
      );

      final activeChild = Child(
        id: 'child-1',
        nickname: 'Maya',
        ageBand: '12-23m',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      sessionState.setActiveChild(activeChild);

      await tester.pumpWidget(
        AuthScope(
          sessionState: sessionState,
          apiClient: ApiClient(baseUrl: 'http://test'),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Child selector chip is rendered when active child exists
      expect(find.byType(ChildChip), findsOneWidget);
      expect(find.text('Maya (12-23m)'), findsOneWidget);

      // Unlabelled header brain icon is omitted in favor of in-situ cards
      expect(find.byIcon(Icons.psychology_outlined), findsNothing);

      final nav = find.byType(NavigationBar);

      // Explore tab shows the shared screen header and catalog filters.
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Explore')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ExploreScreen),
          matching: find.text('Explore'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Simple ideas with things you already have.'),
        findsOneWidget,
      );

      // Switch to This week tab - displays reflection header and formatted age
      await tester.tap(
        find.descendant(of: nav, matching: find.text('This week')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('A look back at the moments you wrote down.'),
        findsOneWidget,
      );
      expect(find.text('For Maya · 12-23 months'), findsOneWidget);

      // Switch to Milestones tab - displays developmental prompt header
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Milestones')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Every child develops at their own pace.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping Add a child in NoChildrenView pushes child registration route',
    (tester) async {
      final sessionState = AuthSessionState(authService: _FakeAuthService());
      await sessionState.signIn(
        email: 'caregiver@example.com',
        password: 'password123',
      );

      bool navigatedToAddChild = false;

      await tester.pumpWidget(
        AuthScope(
          sessionState: sessionState,
          apiClient: ApiClient(baseUrl: 'http://test'),
          child: MaterialApp(
            home: const ShellScreen(),
            routes: {
              '/children/add': (context) {
                navigatedToAddChild = true;
                return const Scaffold(body: Text('Add Child Route'));
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find.text('Add a child');
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(navigatedToAddChild, isTrue);
      expect(find.text('Add Child Route'), findsOneWidget);
    },
  );

  testWidgets('shell switches to NavigationRail on wide viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BrandLogo), findsOneWidget);

    final rail = find.byType(NavigationRail);
    await tester.tap(find.descendant(of: rail, matching: find.text('Explore')));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
  });
}
