import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meditech/screens/customer/landing/landing_screen.dart';
import 'package:meditech/screens/customer/login/login_screen.dart';

void main() {
  // Sign in on the landing page opens the login form
  testWidgets('sign in opens the login screen', (tester) async {
    // A small router with just the two screens this test needs
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
        GoRoute(path: '/sign-in', builder: (_, _) => const LoginScreen()),
      ],
    );

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or mobile'), findsOneWidget);
  });
}