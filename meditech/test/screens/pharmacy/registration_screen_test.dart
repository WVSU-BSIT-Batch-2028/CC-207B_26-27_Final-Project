import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/screens/pharmacy/registration/registration_screen.dart';
import 'package:meditech/screens/pharmacy/registration/location_section.dart';

void main() {

  LocationSection.showMap = false; // no internet in tests
  
  // Continue with empty fields stays on step 1 and shows errors
  testWidgets('empty step 1 cannot continue', (tester) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RegistrationScreen())));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Required.'), findsWidgets);
  });
}