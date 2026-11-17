import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/customer/forgot_password/reset_password_screen.dart';
import 'package:meditech/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  // Different new passwords stay on the screen and are not saved
  testWidgets('mismatched passwords are not saved', (tester) async {
    final fake = MockAuthService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: ResetPasswordScreen(identifier: 'juan@demo.meditech.dev'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), 'Newpass1');
    await tester.enterText(find.byType(TextFormField).at(3), 'Otherpass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    verifyNever(
      () => fake.resetPassword(
        identifier: any(named: 'identifier'),
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });
}
