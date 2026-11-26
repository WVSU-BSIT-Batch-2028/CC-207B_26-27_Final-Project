// Unit tests for page numbers and search matching (lib/utils/paging.dart).

import 'package:agosugnayan/utils/paging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final items = List.generate(30, (i) => i + 1); // 1..30

  test('first page', () {
    final slice = pageOf(items, 1, pageSize: 12);
    expect(slice.items, List.generate(12, (i) => i + 1));
    expect(slice.pageCount, 3);
    expect(slice.summary, 'Showing 1-12 of 30');
    expect(slice.hasPrevious, isFalse);
    expect(slice.hasNext, isTrue);
  });

  test('last page is shorter', () {
    final slice = pageOf(items, 3, pageSize: 12);
    expect(slice.items, [25, 26, 27, 28, 29, 30]);
    expect(slice.summary, 'Showing 25-30 of 30');
    expect(slice.hasNext, isFalse);
  });

  test('a page number that is too big moves to the last page', () {
    // e.g. the user was on page 3, then a filter left only 5 items.
    final slice = pageOf([1, 2, 3, 4, 5], 3, pageSize: 12);
    expect(slice.page, 1);
    expect(slice.items.length, 5);
  });

  test('an empty list has one empty page', () {
    final slice = pageOf(<int>[], 1);
    expect(slice.pageCount, 1);
    expect(slice.summary, 'No results');
  });

  test('matchesSearch needs every word, in any field, any case', () {
    expect(matchesSearch('', ['Tomato']), isTrue);
    expect(matchesSearch('tom', ['Tomato', 'Leon']), isTrue);
    expect(matchesSearch('tom leon', ['Tomato', 'Leon']), isTrue);
    expect(matchesSearch('tom oton', ['Tomato', 'Leon']), isFalse);
  });
}
