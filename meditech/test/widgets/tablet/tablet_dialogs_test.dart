import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet.dart';

void main() {
  testWidgets('showTabletConfirmDialog displays title, bullets, and returns result', (tester) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmed = await showTabletConfirmDialog(
                  context: context,
                  title: 'Confirm RM-103026-0005?',
                  consequences: [
                    'Holds Amoxil x 21 from your stock until pickup, cancellation, or expiry.',
                    'Generates a pickup code and notifies Grace Villanueva.',
                  ],
                  confirmLabel: 'Confirm reservation',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm RM-103026-0005?'), findsOneWidget);
    expect(find.text('WHAT WILL HAPPEN'), findsOneWidget);
    expect(find.textContaining('Holds Amoxil x 21'), findsOneWidget);

    // Tap Confirm button
    await tester.tap(find.text('Confirm reservation'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
