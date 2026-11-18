import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet.dart';

void main() {
  testWidgets('wide fixed-width columns scroll sideways to the last column',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 500,
            child: TabletDataTable<String>(
              totalCount: 1,
              filteredCount: 1,
              columns: const [
                TabletColumn(title: 'FIRST', width: 300),
                TabletColumn(title: 'SECOND', width: 300),
                TabletColumn(title: 'LAST', width: 300),
              ],
              items: const ['row'],
              rowBuilder: (context, item, index) => const [
                Text('first cell'),
                Text('second cell'),
                Text('last cell'),
              ],
            ),
          ),
        ),
      ),
    );

    // The scrollbar is there and the last column starts outside the box
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.getTopLeft(find.text('last cell')).dx, greaterThan(600));

    // Dragging sideways brings the last column into view
    await tester.drag(find.text('FIRST'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('last cell')).dx, lessThan(600));
  });
}