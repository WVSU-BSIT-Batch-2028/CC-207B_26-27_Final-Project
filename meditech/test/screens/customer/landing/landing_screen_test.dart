import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meditech/screens/customer/landing/landing_screen.dart';
import 'package:meditech/screens/customer/login/login_screen.dart';
import 'package:meditech/screens/customer/sign_up/sign_up_screen.dart';

void main() {
  // Sign in on the landing page opens the login form
  testWidgets('sign in opens the login screen', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
        GoRoute(path: '/sign-in', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
      ],
    );

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));

    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email or mobile'), findsOneWidget);
  });

  // Get started opens create account
  testWidgets('get started opens sign up', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
        GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('Home'))),
      ],
    );

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));

    await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });
}
