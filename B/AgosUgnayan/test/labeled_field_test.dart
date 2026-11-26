// Widget test for LabeledField: required fields get a red star, the others
// an "Optional" tag, and the help line shows under the field.

import 'package:agosugnayan/widgets/labeled_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('a required field shows a star, not Optional', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LabeledField(
          label: 'Crop',
          isRequired: true,
          help: 'Choose a crop to see the latest PSA farmgate price.',
          child: TextField(),
        ),
      ),
    );
    expect(find.textContaining('Crop *', findRichText: true), findsOneWidget);
    expect(find.text('Optional'), findsNothing);
    expect(
      find.text('Choose a crop to see the latest PSA farmgate price.'),
      findsOneWidget,
    );
  });

  testWidgets('an optional field shows the Optional tag', (tester) async {
    await tester.pumpWidget(
      _wrap(const LabeledField(label: 'Description', child: TextField())),
    );
    expect(find.text('Optional'), findsOneWidget);
  });
}
