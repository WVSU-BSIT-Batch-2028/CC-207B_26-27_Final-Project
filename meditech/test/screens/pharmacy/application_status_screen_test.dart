import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/application_status.dart';
import 'package:meditech/providers/application_providers.dart';
import 'package:meditech/screens/pharmacy/registration/application_status_screen.dart';

// Shows the screen with a pretend application instead of the database
Widget screenWith(ApplicationStatus app) => ProviderScope(
      overrides: [myApplicationProvider.overrideWith((ref) async => app)],
      child: const MaterialApp(home: ApplicationStatusScreen()),
    );

void main() {
  // A rejected application shows the reason and the resubmit button
  testWidgets('rejected shows the reason', (tester) async {
    await tester.pumpWidget(screenWith(ApplicationStatus(
      displayId: 'PHM-000009',
      pharmacyName: 'Farmacia Uno',
      branchName: 'Main Branch',
      status: 'rejected',
      submittedAt: DateTime(2026, 11, 14),
      rejectionReason: "The address on your LTO doesn't match.",
    )));
    await tester.pumpAndSettle();

    expect(find.text('Application not approved'), findsOneWidget);
    expect(find.text("The address on your LTO doesn't match."), findsOneWidget);
    expect(find.text('Edit and resubmit'), findsOneWidget);
  });

  // A waiting application shows "under review"
  testWidgets('pending shows under review', (tester) async {
    await tester.pumpWidget(screenWith(ApplicationStatus(
      displayId: 'PHM-000009',
      pharmacyName: 'Farmacia Uno',
      branchName: 'Main Branch',
      status: 'pending_approval',
      submittedAt: DateTime(2026, 11, 14),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Application under review'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });
}