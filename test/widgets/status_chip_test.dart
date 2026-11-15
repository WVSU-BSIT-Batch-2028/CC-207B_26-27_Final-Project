import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:websupark/widgets/status_chip.dart';

void main() {
  testWidgets('StatusChip shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(label: 'Active', kind: StatusKind.success),
        ),
      ),
    );

    expect(find.text('Active'), findsOneWidget);
  });
}