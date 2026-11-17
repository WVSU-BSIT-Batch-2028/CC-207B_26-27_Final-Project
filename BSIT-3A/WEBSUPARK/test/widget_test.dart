import 'package:flutter_test/flutter_test.dart';
import 'package:websupark/main.dart';

void main() {
  // Smoke test: checks that the app starts and shows the placeholder screen.
  testWidgets('App starts and shows the placeholder text', (tester) async {
    // Build the app and draw one frame.
    await tester.pumpWidget(const WebsuParkApp());

    // Look for the text shown by PlaceholderScreen in lib/main.dart.
    expect(find.text('WEBSUPARK\nProject setup OK'), findsOneWidget);
  });
}