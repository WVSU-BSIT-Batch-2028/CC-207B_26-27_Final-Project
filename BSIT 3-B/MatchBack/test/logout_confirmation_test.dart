import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchback/main.dart';
import 'package:matchback/services/auth_service.dart';

void main() {
  for (final role in UserRole.values) {
    for (final wide in [true, false]) {
      testWidgets(
        '${role.name} ${wide ? 'desktop' : 'mobile'} logout confirmation',
        (tester) async {
          tester.view.physicalSize = Size(wide ? 1800 : 850, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var logoutCount = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: MatchBackHomePage(
                session: AppSession(uid: 'test', role: role, studentId: 'test'),
                onLogout: () => logoutCount++,
              ),
            ),
          );
          await tester.pump();

          Future<void> openLogout() async {
            if (wide) {
              await tester.tap(find.byTooltip('Log out'));
            } else {
              await tester.tap(find.byType(PopupMenuButton<int>));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Log out'));
            }
            await tester.pumpAndSettle();
          }

          await openLogout();
          expect(
            find.text('Are you sure you want to log out?'),
            findsOneWidget,
          );
          await tester.tap(find.text('Stay signed in'));
          await tester.pumpAndSettle();
          expect(logoutCount, 0);

          await openLogout();
          await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
          await tester.pumpAndSettle();
          expect(logoutCount, 1);
        },
      );
    }
  }
}
