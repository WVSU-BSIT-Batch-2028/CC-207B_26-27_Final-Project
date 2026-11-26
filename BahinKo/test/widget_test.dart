import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/screens/main_pages_preview.dart';

void main() {
  testWidgets('main UI tabs display their pages', (tester) async {
    await tester.pumpWidget(const BahinKoPreviewApp());

    expect(find.text('Net balance'), findsOneWidget);
    expect(find.text('Weekend Trip'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Santos'), findsOneWidget);
  });
}
