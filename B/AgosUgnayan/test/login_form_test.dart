// Widget test for the login form: empty or wrong input shows clear errors
// before anything is sent to Firebase.

import 'package:agosugnayan/screens/login_screen.dart';
import 'package:agosugnayan/utils/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows errors when the fields are empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.text('Log in'));
    await tester.pump();
    // Both fields are required.
    expect(find.text(AppStrings.fieldRequired), findsNWidgets(2));
  });

  testWidgets('shows an error for a bad email and short password', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'pedro');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text(AppStrings.emailInvalid), findsOneWidget);
    expect(find.text(AppStrings.passwordTooShort), findsOneWidget);
  });
}
