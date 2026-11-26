import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synergy_flutter/main.dart';

void main() {
  testWidgets('Sign in rejects a wrong password', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SynergyApp());
    await tester.pumpAndSettle();

    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    expect(signIn, findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'budgetbuddy@demo.test');
    await tester.enterText(fields.at(1), 'incorrect123');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password'), findsOneWidget);
  });
}
