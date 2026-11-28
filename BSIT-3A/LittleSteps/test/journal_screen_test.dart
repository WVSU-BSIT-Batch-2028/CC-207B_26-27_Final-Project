import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/models/journal_entry.dart';
import 'package:littlesteps/screens/journal/journal_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/services/journal_service.dart';
import 'package:littlesteps/theme/app_theme.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

// Widget tests for the journal list and note form (issue #7).

/// A [JournalService] that never calls the API, so each test controls what
/// the journal screens receive.
///
/// It keeps the notes in memory: saving and deleting change [entries], so
/// the list shows the change when it reloads, like the real app.
class _FakeJournalService extends JournalService {
  _FakeJournalService({List<JournalEntry> entries = const [], this.error})
    : entries = List.of(entries),
      super(apiClient: ApiClient(baseUrl: 'http://test'));

  /// The notes returned by [getJournalEntries].
  final List<JournalEntry> entries;

  /// When set, [getJournalEntries] throws this instead of returning
  /// [entries], for example a `NoConnectionApiException`.
  Object? error;

  /// When set, saving a note throws this instead of saving it.
  Object? saveError;

  /// Whether [deleteJournalEntry] was called, so a test can check that
  /// Cancel keeps the note and Delete removes it.
  bool deleted = false;

  /// Returns [entries], or throws [error] when it is set.
  @override
  Future<List<JournalEntry>> getJournalEntries(String childId) async {
    if (error != null) throw error!;
    return entries;
  }

  /// Adds a new note to [entries], or throws [saveError] when it is set.
  @override
  Future<JournalEntry> createJournalEntry({
    required String childId,
    required String entryDate,
    required String content,
  }) async {
    if (saveError != null) throw saveError!;
    final entry = _entry(
      id: 'new-${entries.length}',
      entryDate: entryDate,
      content: content,
    );
    entries.add(entry);
    return entry;
  }

  /// Replaces the note with [entryId] in [entries].
  @override
  Future<JournalEntry> updateJournalEntry({
    required String childId,
    required String entryId,
    required String content,
    String? entryDate,
  }) async {
    if (saveError != null) throw saveError!;
    final index = entries.indexWhere((entry) => entry.id == entryId);
    final updated = _entry(
      id: entryId,
      entryDate: entryDate ?? entries[index].entryDate,
      content: content,
    );
    entries[index] = updated;
    return updated;
  }

  /// Records the call and removes the note from [entries].
  @override
  Future<void> deleteJournalEntry({
    required String childId,
    required String entryId,
  }) async {
    deleted = true;
    entries.removeWhere((entry) => entry.id == entryId);
  }
}

/// An [AuthService] that signs in anyone without a network call.
/// Copied from `widget_test.dart`.
class _FakeAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: 'test-user',
      email: email,
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: 'test-user',
      email: email,
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    return AuthUser(
      id: 'test-user',
      email: 'test@example.com',
      idToken: 'token',
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> signOut() async {}
}

/// Builds a note for the child with id `child-1`, with fixed timestamps.
JournalEntry _entry({
  required String id,
  required String entryDate,
  required String content,
}) {
  return JournalEntry(
    id: id,
    childId: 'child-1',
    entryDate: entryDate,
    content: content,
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
  );
}

/// Signs in a caregiver, makes Mia the active child, and shows the
/// journal tab using [service]. It does not wait for the notes to load,
/// so a test can check the loading state first.
Future<void> _pumpJournal(
  WidgetTester tester,
  _FakeJournalService service,
) async {
  final sessionState = AuthSessionState(authService: _FakeAuthService());
  await sessionState.signIn(
    email: 'caregiver@example.com',
    password: 'password123',
  );
  sessionState.setActiveChild(
    Child(
      id: 'child-1',
      nickname: 'Mia',
      ageBand: '12-23m',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );

  await tester.pumpWidget(
    AuthScope(
      sessionState: sessionState,
      apiClient: service.apiClient,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: JournalScreen(journalService: service)),
      ),
    ),
  );
}

/// Taps the widget [finder] finds, scrolling it into view first, and
/// waits for the screen to settle.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // The scroll only takes effect on the next frame.
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  final cupsNote = _entry(
    id: 'note-1',
    entryDate: '2026-11-20',
    content: 'Mia stacked four cups.',
  );
  final wordNote = _entry(
    id: 'note-2',
    entryDate: '2026-11-22',
    content: 'Mia said "ball" today.',
  );

  group('JournalScreen list', () {
    testWidgets('shows loading, then every note', (tester) async {
      await _pumpJournal(
        tester,
        _FakeJournalService(entries: [cupsNote, wordNote]),
      );
      expect(find.text('Loading notes...'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Mia stacked four cups.'), findsOneWidget);
      expect(find.text('Mia said "ball" today.'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no notes', (
      tester,
    ) async {
      await _pumpJournal(tester, _FakeJournalService());
      await tester.pumpAndSettle();

      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('search shows only matching notes', (tester) async {
      await _pumpJournal(
        tester,
        _FakeJournalService(entries: [cupsNote, wordNote]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Search notes'),
        'CUPS',
      );
      await tester.pumpAndSettle();
      expect(find.text('Mia stacked four cups.'), findsOneWidget);
      expect(find.text('Mia said "ball" today.'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search notes'),
        'giraffe',
      );
      await tester.pumpAndSettle();
      expect(find.text('No notes match your search'), findsOneWidget);
    });

    testWidgets('shows the offline view when there is no connection', (
      tester,
    ) async {
      await _pumpJournal(
        tester,
        _FakeJournalService(error: NoConnectionApiException()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Your notes will show when you reconnect.'),
        findsOneWidget,
      );
    });

    testWidgets('shows access denied for a 404', (tester) async {
      await _pumpJournal(
        tester,
        _FakeJournalService(
          error: NotFoundApiException(code: 'NOT_FOUND', message: 'Not found'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("This journal isn't available"), findsOneWidget);
      // J4: nothing from the server's error is shown.
      expect(find.text('Not found'), findsNothing);
    });
  });

  group('JournalNoteScreen form', () {
    testWidgets('an empty note shows "Write a note" and is not saved', (
      tester,
    ) async {
      final service = _FakeJournalService();
      await _pumpJournal(tester, service);
      await tester.pumpAndSettle();

      await _tap(tester, find.text('New note'));
      await _tap(tester, find.text('Save note'));

      expect(find.text('Write a note'), findsOneWidget);
      expect(service.entries, isEmpty);
    });

    testWidgets('saving a new note shows it in the list', (tester) async {
      final service = _FakeJournalService();
      await _pumpJournal(tester, service);
      await tester.pumpAndSettle();

      await _tap(tester, find.text('New note'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'What did you notice?'),
        'Mia waved goodbye.',
      );
      await _tap(tester, find.text('Save note'));

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Mia waved goodbye.'), findsOneWidget);
    });

    testWidgets('saving while offline keeps the typed note', (tester) async {
      final service = _FakeJournalService()
        ..saveError = NoConnectionApiException();
      await _pumpJournal(tester, service);
      await tester.pumpAndSettle();

      await _tap(tester, find.text('New note'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'What did you notice?'),
        'Mia waved goodbye.',
      );
      await _tap(tester, find.text('Save note'));

      expect(
        find.text('Reconnect to save changes. Your note is kept here.'),
        findsOneWidget,
      );
      expect(find.text('Mia waved goodbye.'), findsOneWidget);
    });

    testWidgets('editing a note fills the form and saves the change', (
      tester,
    ) async {
      final service = _FakeJournalService(entries: [cupsNote]);
      await _pumpJournal(tester, service);
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Mia stacked four cups.'));
      expect(find.text('Edit note'), findsOneWidget);
      expect(find.text('Mia stacked four cups.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'What did you notice?'),
        'Mia stacked five cups.',
      );
      await _tap(tester, find.text('Save note'));

      expect(find.text('Mia stacked five cups.'), findsOneWidget);
      expect(find.text('Mia stacked four cups.'), findsNothing);
    });
  });

  group('Deleting a note', () {
    testWidgets('Cancel keeps the note', (tester) async {
      final service = _FakeJournalService(entries: [cupsNote]);
      await _pumpJournal(tester, service);
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Mia stacked four cups.'));
      await _tap(tester, find.byTooltip('Delete note'));
      expect(find.text('Delete this note?'), findsOneWidget);

      await _tap(tester, find.text('Cancel'));
      expect(service.deleted, isFalse);
      expect(find.text('Edit note'), findsOneWidget);
    });

    testWidgets('Delete removes the note from the list', (tester) async {
      final service = _FakeJournalService(entries: [cupsNote]);
      await _pumpJournal(tester, service);
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Mia stacked four cups.'));
      await _tap(tester, find.byTooltip('Delete note'));
      await _tap(tester, find.text('Delete'));

      expect(service.deleted, isTrue);
      expect(find.text('No notes yet'), findsOneWidget);
    });
  });

  testWidgets('the note form fits a phone at 200% text size', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpJournal(tester, _FakeJournalService(entries: [cupsNote]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _tap(tester, find.text('Mia stacked four cups.'));
    expect(tester.takeException(), isNull);

    // At 200% the Save button starts below the screen, and the list only
    // builds rows on screen, so scroll down to it like a caregiver would.
    // `.first` is the form's list; the note box has its own scrollable.
    await tester.scrollUntilVisible(
      find.text('Save note'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Save note'), findsOneWidget);
  });
}
