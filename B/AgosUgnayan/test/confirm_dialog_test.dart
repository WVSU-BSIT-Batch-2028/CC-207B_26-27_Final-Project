// Widget tests for showConfirmDialog: Delete returns true, Cancel returns false.

import 'package:agosugnayan/utils/strings.dart';
import 'package:agosugnayan/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the dialog from a button and stores the answer in [onResult].
Widget _app(void Function(bool) onResult) {
  return MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => onResult(
          await showConfirmDialog(
            context,
            title: 'Delete this crop?',
            message: 'It will be removed.',
            confirmLabel: AppStrings.delete,
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

void main() {
  testWidgets('Delete returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(_app((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Cancel returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(_app((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
