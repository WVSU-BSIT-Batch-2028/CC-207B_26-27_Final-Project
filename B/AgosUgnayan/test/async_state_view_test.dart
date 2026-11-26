// Widget tests for AsyncStateView: it shows the right thing for loading,
// error, empty and data, and the Try again button calls onRetry.

import 'package:agosugnayan/utils/strings.dart';
import 'package:agosugnayan/widgets/async_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps the widget in the minimum app needed to render it.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows a spinner while loading', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncStateView(
          isLoading: true,
          isEmpty: false,
          emptyMessage: 'Nothing',
          builder: (_) => const Text('Data'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Data'), findsNothing);
  });

  testWidgets('shows the error and Try again calls onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        AsyncStateView(
          isLoading: false,
          errorMessage: AppStrings.networkError,
          onRetry: () => retried = true,
          isEmpty: false,
          emptyMessage: 'Nothing',
          builder: (_) => const Text('Data'),
        ),
      ),
    );
    expect(find.text(AppStrings.networkError), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    expect(retried, isTrue);
  });

  testWidgets('shows the empty message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncStateView(
          isLoading: false,
          isEmpty: true,
          emptyMessage: 'No crops yet.',
          builder: (_) => const Text('Data'),
        ),
      ),
    );
    expect(find.text('No crops yet.'), findsOneWidget);
  });

  testWidgets('shows the data', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncStateView(
          isLoading: false,
          isEmpty: false,
          emptyMessage: 'Nothing',
          builder: (_) => const Text('Data'),
        ),
      ),
    );
    expect(find.text('Data'), findsOneWidget);
  });
}
