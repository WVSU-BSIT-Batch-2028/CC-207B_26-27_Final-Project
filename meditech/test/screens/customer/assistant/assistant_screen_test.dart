import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/assistant_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/customer/assistant/assistant_screen.dart';
import 'package:meditech/services/assistant_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockAssistantService extends Mock implements AssistantService {}

void main() {
  // A reply from the function is shown under the question
  testWidgets('shows the assistant reply', (tester) async {
    final fake = MockAssistantService();
    when(() => fake.ask(any())).thenAnswer((_) async => 'Biogesic is listed in MediTech.');

    await tester.pumpWidget(_app(fake));
    await tester.enterText(find.byType(TextFormField), 'where can I find paracetamol');
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('where can I find paracetamol'), findsOneWidget);
    expect(find.text('Biogesic is listed in MediTech.'), findsOneWidget);
  });

  // An unavailable assistant shows that message instead of a blank page
  testWidgets('shows the unavailable message', (tester) async {
    final fake = MockAssistantService();
    when(() => fake.ask(any())).thenThrow(const AppFailure('The assistant is unavailable.'));

    await tester.pumpWidget(_app(fake));
    await tester.enterText(find.byType(TextFormField), 'where can I find paracetamol');
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('The assistant is unavailable.'), findsOneWidget);
  });
}

Widget _app(AssistantService fake) {
  return ProviderScope(
    overrides: [
      assistantServiceProvider.overrideWithValue(fake),
      sessionProvider.overrideWith(_SignedIn.new),
    ],
    child: const MaterialApp(home: AssistantScreen()),
  );
}

class _SignedIn extends SessionNotifier {
  @override
  SignedInAccount? build() {
    return const SignedInAccount(accountType: 'customer', state: 'active');
  }
}