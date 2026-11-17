import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet.dart';

void main() {
  testWidgets('TabletDataTable displays search, count, headers, and rows', (tester) async {
    final rows = ['Biogesic', 'Amoxil', 'Cozaar'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 600,
            child: TabletDataTable<String>(
              searchHint: 'Search medicine',
              totalCount: 3,
              filteredCount: 3,
              countLabel: 'medicines',
              columns: const [
                TabletColumn(title: 'MEDICINE', flex: 2),
                TabletColumn(title: 'ACTION', flex: 1),
              ],
              items: rows,
              rowBuilder: (context, item, index) => [
                Text(item),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('3 of 3 medicines'), findsOneWidget);
    expect(find.text('MEDICINE'), findsOneWidget);
    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Amoxil'), findsOneWidget);
    expect(find.text('Cozaar'), findsOneWidget);
  });
}
