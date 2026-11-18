import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet.dart';

void main() {
  testWidgets('cells align under matching headers when some columns are hidden',
      (tester) async {
    // Column priorities: A is high (always visible), B is low (hidden under 950px), C is high (always visible)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: TabletDataTable<String>(
              totalCount: 1,
              filteredCount: 1,
              columns: const [
                TabletColumn(title: 'COL_A', priority: TabletColumnPriority.high),
                TabletColumn(title: 'COL_B', priority: TabletColumnPriority.low),
                TabletColumn(title: 'COL_C', priority: TabletColumnPriority.high),
              ],
              items: const ['item1'],
              rowBuilder: (context, item, index) => const [
                Text('cell_a'),
                Text('cell_b'),
                Text('cell_c'),
              ],
            ),
          ),
        ),
      ),
    );

    // COL_A and COL_C headers should be visible; COL_B should be hidden
    expect(find.text('COL_A'), findsOneWidget);
    expect(find.text('COL_B'), findsNothing);
    expect(find.text('COL_C'), findsOneWidget);

    // cell_a and cell_c should be visible; cell_b should not be displayed
    expect(find.text('cell_a'), findsOneWidget);
    expect(find.text('cell_b'), findsNothing);
    expect(find.text('cell_c'), findsOneWidget);
  });
}
