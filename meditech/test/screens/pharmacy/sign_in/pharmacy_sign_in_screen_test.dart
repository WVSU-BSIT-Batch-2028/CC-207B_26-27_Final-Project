import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/pharmacy/sign_in/pharmacy_sign_in_screen.dart';
import 'package:meditech/services/auth_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  // The branch sign-in matches the wireframe labels
  testWidgets('shows the branch sign-in layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PharmacySignInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your branch'), findsOneWidget);
    expect(find.textContaining('Shared logins'), findsOneWidget);
    expect(find.textContaining('10 minutes of inactivity'), findsOneWidget);
    expect(find.text('Register your pharmacy'), findsOneWidget);
    expect(find.textContaining('Already applied'), findsOneWidget);
  });

  // A locked pharmacy account shows the 15-minute message
  testWidgets('lockout message is shown', (tester) async {
    final fake = MockAuthService();
    when(
      () => fake.signIn(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
        app: any(named: 'app'),
      ),
    ).thenThrow(
      const AppFailure('Too many wrong passwords. Try again in 15 minutes.'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: PharmacySignInScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'demo_pharma');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many wrong passwords. Try again in 15 minutes.'),
      findsOneWidget,
    );
  });

  // Register opens Lyka's registration form
  testWidgets('register button opens registration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PharmacySignInScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const Scaffold(
            body: Text('Registration form'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final register = find.text('Register your pharmacy');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pumpAndSettle();

    expect(find.text('Registration form'), findsOneWidget);
  });
}
