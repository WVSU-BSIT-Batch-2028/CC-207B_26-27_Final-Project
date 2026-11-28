import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/account/account_info_screen.dart';
import 'package:littlesteps/screens/account/settings_screen.dart';
import 'package:littlesteps/screens/shell_screen.dart';
import 'package:littlesteps/services/account_service.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/children_service.dart';
import 'package:littlesteps/theme/app_theme.dart';

void main() {
  testWidgets('account menu opens from the header and shows its actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const ShellScreen(email: 'caregiver@example.com'),
      ),
    );

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();

    expect(find.text('caregiver@example.com'), findsOneWidget);
    expect(find.text('Add a child'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Privacy notice'), findsOneWidget);
    expect(find.text('About LittleSteps'), findsOneWidget);
    expect(find.text('Help and support'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(
      find.text('If you share this phone, sign out when you are done.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Your data'), findsOneWidget);
    expect(find.text('Download my data'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
  });

  testWidgets('privacy notice explains data use, AI and caregiver choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountInfoScreen(page: AccountInfoPage.privacy)),
    );

    for (final heading in [
      'What we collect',
      'Why we use it',
      'What stays private',
      'The Idea helper',
      'How long we keep it',
      'Your choices',
    ]) {
      await tester.scrollUntilVisible(
        find.text(heading),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(heading), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.textContaining('Journal notes are not sent'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Journal notes are not sent'), findsOneWidget);
  });

  testWidgets('account menu sends a selected child to shared app state', (
    tester,
  ) async {
    final child = Child(
      id: 'child-1',
      nickname: 'Maya',
      ageBand: '12-23m',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    Child? selectedChild;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ShellScreen(
          children: [child],
          activeChildId: 'other-child',
          onChildSelected: (value) => selectedChild = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maya'));
    await tester.pumpAndSettle();

    expect(selectedChild?.id, child.id);
  });

  testWidgets('help page includes product, concern and contact guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountInfoScreen(page: AccountInfoPage.help)),
    );

    for (final heading in [
      'How LittleSteps works',
      'Worried about your child?',
      'Contact us',
    ]) {
      await tester.scrollUntilVisible(
        find.text(heading),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(heading), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text(
        'Children develop at different rates. Talk to a health professional '
        'if you have concerns.',
      ),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'Children develop at different rates. Talk to a health professional '
        'if you have concerns.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('child deletion confirmation names the child and records', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          accountService: _FakeAccountService(),
          childrenService: _FakeChildrenService(),
          children: [
            Child(
              id: 'child-1',
              nickname: 'Maya',
              ageBand: '12-23m',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Delete Maya’s records'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Maya’s records?'), findsOneWidget);
    expect(
      find.textContaining('profile, plans, observations, journal entries'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Maya’s records?'), findsNothing);
  });

  testWidgets('account deletion confirmation names data that will be removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(accountService: _FakeAccountService())),
    );

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(
      find.textContaining(
        'all child profiles, plans, observations, journal entries',
      ),
      findsOneWidget,
    );
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets(
    'about page lists developmental sources with clinical citations and URLs',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccountInfoScreen(page: AccountInfoPage.about)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where content comes from'), findsOneWidget);
      expect(
        find.textContaining('CDC Developmental Milestones'),
        findsOneWidget,
      );
      expect(
        find.textContaining('American Academy of Pediatrics (AAP)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('WHO Nurturing Care Framework'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Philippine Early Learning Standards (ECCD Council)',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('DepEd MATATAG Kindergarten Curriculum'),
        findsOneWidget,
      );
      expect(find.textContaining('cdc.gov'), findsOneWidget);
      expect(find.textContaining('healthychildren.org'), findsOneWidget);
      expect(find.textContaining('eccdcouncil.gov.ph'), findsOneWidget);
      expect(find.textContaining('deped.gov.ph'), findsOneWidget);
      expect(find.textContaining('https://'), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(5));
    },
  );

  testWidgets('deleting the last child removes it and invokes onChildDeleted', (
    tester,
  ) async {
    String? deletedChildId;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          email: 'ana@example.com',
          children: [
            Child(
              id: 'c1',
              nickname: 'Maya',
              ageBand: '12-23m',
              createdAt: DateTime(2026, 11, 24),
              updatedAt: DateTime(2026, 11, 24),
            ),
          ],
          accountService: _FakeAccountService(),
          childrenService: _FakeChildrenService(),
          onChildDeleted: (id) => deletedChildId = id,
        ),
      ),
    );

    expect(
      find.text(
        'Account actions will be available after sign-in is connected.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Delete Maya’s records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete records'));
    await tester.pumpAndSettle();

    expect(deletedChildId, 'c1');
    expect(find.text('No children added yet'), findsOneWidget);
  });
}

class _FakeAccountService extends AccountService {
  _FakeAccountService() : super(apiClient: ApiClient(baseUrl: 'http://test'));

  @override
  Future<void> deleteAccount() async {}
}

class _FakeChildrenService extends ChildrenService {
  _FakeChildrenService() : super(apiClient: ApiClient(baseUrl: 'http://test'));

  @override
  Future<void> deleteChild(String id) async {}
}
