import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/customer_profile.dart';
import 'package:meditech/providers/profile_providers.dart';
import 'package:meditech/screens/customer/profile/privacy_notice_screen.dart';
import 'package:meditech/screens/customer/profile/profile_screen.dart';
import 'package:meditech/services/profile_service.dart';

void main() {
  // The profile page shows the details saved for this customer
  testWidgets('profile shows the saved details', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileServiceProvider.overrideWithValue(_FakeProfileService())],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('09170000001'), findsOneWidget);
    expect(find.text('juan@demo.meditech.dev'), findsOneWidget);
    expect(find.text('1995-06-15'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
  });

  // The privacy page shows notice v1
  testWidgets('privacy notice is shown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyNoticeScreen()));

    expect(find.text('MediTech privacy notice v1'), findsOneWidget);
  });
}

class _FakeProfileService implements ProfileService {
  @override
  Future<CustomerProfile?> loadMine() async {
    return const CustomerProfile(
      firstName: 'Juan',
      lastName: 'Dela Cruz',
      mobile: '09170000001',
      email: 'juan@demo.meditech.dev',
      birthdate: '1995-06-15',
      consentVersion: 'v1',
    );
  }
}