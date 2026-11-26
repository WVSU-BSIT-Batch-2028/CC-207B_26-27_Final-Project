// Page numbers for long lists: which items belong on page 3 when there are
// 12 per page, and the "Showing 25-36 of 57" text. Kept apart from the
// widgets so it is easy to unit-test.

/// One page of a list, plus what the pagination bar needs to know.
class PageSlice<T> {
  const PageSlice({
    required this.items,
    required this.page,
    required this.pageCount,
    required this.total,
    required this.start,
  });

  /// The items on this page.
  final List<T> items;

  /// This page's number, starting at 1.
  final int page;

  /// How many pages there are (at least 1, even for an empty list).
  final int pageCount;

  /// How many items there are on all pages together.
  final int total;

  /// Position of this page's first item, counting from 1 (0 when empty).
  final int start;

  /// Position of this page's last item.
  int get end => start == 0 ? 0 : start + items.length - 1;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < pageCount;

  /// e.g. "Showing 13-24 of 57".
  String get summary =>
      total == 0 ? 'No results' : 'Showing $start-$end of $total';
}

/// The items of page [page] (starting at 1) when each page has [pageSize]
/// items. A page number that is too big or too small is moved into range,
/// so a filter that shrinks the list never shows an empty page by mistake.
PageSlice<T> pageOf<T>(List<T> all, int page, {int pageSize = 12}) {
  final pageCount = all.isEmpty ? 1 : (all.length / pageSize).ceil();
  final safePage = page.clamp(1, pageCount);
  final from = (safePage - 1) * pageSize;
  final to = (from + pageSize).clamp(0, all.length);
  return PageSlice(
    items: all.sublist(from.clamp(0, all.length), to),
    page: safePage,
    pageCount: pageCount,
    total: all.length,
    start: all.isEmpty ? 0 : from + 1,
  );
}

/// True when [query] is empty or every word of it appears somewhere in
/// [fields] (ignoring upper/lower case). "tom leon" matches a tomato
/// listing in Leon.
bool matchesSearch(String query, List<String> fields) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return true;
  final text = fields.join(' ').toLowerCase();
  return words.every(text.contains);
}
