import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue_medicine.dart';
import '../models/drug_registration.dart';
import '../models/verification_check.dart';
import '../services/catalogue_service.dart';

// Gives screens the catalogue service
final catalogueServiceProvider = Provider<CatalogueService>(
  (ref) => CatalogueService(Supabase.instance.client),
);

// Columns the table can be sorted by
enum CatalogueSort { generic, brand, registration }

const _keep = Object();

// What the admin chose: status tab, search, extra filters, sort, and page
class CatalogueFilter {
  const CatalogueFilter({
    this.status,
    this.search = '',
    this.isRx,
    this.fdaMatched,
    this.sort = CatalogueSort.generic,
    this.ascending = true,
    this.page = 0,
    this.perPage = 10,
  });

  final String? status; // null means All
  final String search;
  final bool? isRx; // null means any classification
  final bool? fdaMatched; // null means any FDA check result
  final CatalogueSort sort;
  final bool ascending;
  final int page; // zero-based
  final int perPage;

  // How many of the "More filters" are on
  int get extraFilterCount => (isRx != null ? 1 : 0) + (fdaMatched != null ? 1 : 0);

  CatalogueFilter copyWith({
    Object? status = _keep,
    String? search,
    Object? isRx = _keep,
    Object? fdaMatched = _keep,
    CatalogueSort? sort,
    bool? ascending,
    int? page,
    int? perPage,
  }) =>
      CatalogueFilter(
        status: identical(status, _keep) ? this.status : status as String?,
        search: search ?? this.search,
        isRx: identical(isRx, _keep) ? this.isRx : isRx as bool?,
        fdaMatched: identical(fdaMatched, _keep) ? this.fdaMatched : fdaMatched as bool?,
        sort: sort ?? this.sort,
        ascending: ascending ?? this.ascending,
        page: page ?? this.page,
        perPage: perPage ?? this.perPage,
      );
}

class CatalogueFilterController extends Notifier<CatalogueFilter> {
  @override
  CatalogueFilter build() => const CatalogueFilter();

  // Changing what's shown always goes back to page 1
  void setStatus(String? status) => state = state.copyWith(status: status, page: 0);
  void setSearch(String search) => state = state.copyWith(search: search.trim(), page: 0);
  void setRx(bool? isRx) => state = state.copyWith(isRx: isRx, page: 0);
  void setFdaMatched(bool? matched) => state = state.copyWith(fdaMatched: matched, page: 0);
  void clearExtraFilters() => state = state.copyWith(isRx: null, fdaMatched: null, page: 0);
  void setPerPage(int perPage) => state = state.copyWith(perPage: perPage, page: 0);
  void setPage(int page) => state = state.copyWith(page: page);

  void setSort(CatalogueSort sort, {bool? ascending}) =>
      state = state.copyWith(sort: sort, ascending: ascending ?? true, page: 0);

  // Tapping the same column flips the order; a new column starts A to Z
  void toggleSort(CatalogueSort sort) =>
      setSort(sort, ascending: state.sort == sort ? !state.ascending : true);
}

final catalogueFilterProvider =
    NotifierProvider<CatalogueFilterController, CatalogueFilter>(CatalogueFilterController.new);

// Every catalogue entry; searching, filtering, sorting, and paging happen on the device
final catalogueListProvider = FutureProvider.autoDispose<List<CatalogueMedicine>>(
  (ref) => ref.read(catalogueServiceProvider).list(),
);

// One page of the table, plus the counts the filters and pager need
class CatalogueView {
  const CatalogueView({
    required this.statusCounts,
    required this.matching,
    required this.rows,
    required this.page,
    required this.pageCount,
    required this.firstShown,
    required this.lastShown,
  });

  final Map<String?, int> statusCounts; // per status tab (null = All), before the tab is applied
  final int matching; // entries that pass every filter
  final List<CatalogueMedicine> rows; // this page only
  final int page; // zero-based, kept within range
  final int pageCount;
  final int firstShown; // 1-based, 0 when nothing matches
  final int lastShown;

  factory CatalogueView.of(List<CatalogueMedicine> all, CatalogueFilter f) {
    final q = f.search.toLowerCase();
    bool searched(CatalogueMedicine m) =>
        q.isEmpty ||
        [m.brandName, m.genericName, m.displayId, m.registrationNumber ?? '']
            .any((s) => s.toLowerCase().contains(q));

    // Search and "More filters" first, so the status tabs can show their counts
    final narrowed = all
        .where((m) =>
            searched(m) &&
            (f.isRx == null || m.isRx == f.isRx) &&
            (f.fdaMatched == null || m.fdaMatched == f.fdaMatched))
        .toList();

    final counts = <String?, int>{null: narrowed.length};
    for (final m in narrowed) {
      counts[m.status] = (counts[m.status] ?? 0) + 1;
    }

    final shown = f.status == null ? narrowed : narrowed.where((m) => m.status == f.status).toList();

    String key(CatalogueMedicine m) => switch (f.sort) {
          CatalogueSort.generic => m.genericName,
          CatalogueSort.brand => m.brandName,
          // Entries without a registration go last either way
          CatalogueSort.registration => m.registrationNumber ?? '',
        }
            .toLowerCase();
    shown.sort((a, b) {
      final ka = key(a), kb = key(b);
      if (f.sort == CatalogueSort.registration && (ka.isEmpty || kb.isEmpty) && ka != kb) {
        return ka.isEmpty ? 1 : -1;
      }
      final byKey = f.ascending ? ka.compareTo(kb) : kb.compareTo(ka);
      if (byKey != 0) return byKey;
      return '${a.genericName} ${a.brandName} ${a.strength}'
          .toLowerCase()
          .compareTo('${b.genericName} ${b.brandName} ${b.strength}'.toLowerCase());
    });

    final pageCount = shown.isEmpty ? 1 : (shown.length / f.perPage).ceil();
    final page = f.page.clamp(0, pageCount - 1);
    final start = page * f.perPage;
    final end = (start + f.perPage).clamp(0, shown.length);

    return CatalogueView(
      statusCounts: counts,
      matching: shown.length,
      rows: shown.sublist(start, end),
      page: page,
      pageCount: pageCount,
      firstShown: shown.isEmpty ? 0 : start + 1,
      lastShown: end,
    );
  }
}

// The open drawer: null = closed, 'new' = adding, otherwise a medicine id
class SelectedMedicineController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedMedicineProvider =
    NotifierProvider<SelectedMedicineController, String?>(SelectedMedicineController.new);

// Short lists for the drop-downs
final dosageFormsProvider = FutureProvider<List<LookupItem>>(
  (ref) => ref.read(catalogueServiceProvider).dosageForms(),
);
final unitsProvider = FutureProvider<List<LookupItem>>(
  (ref) => ref.read(catalogueServiceProvider).units(),
);

// One registration's details
final registrationProvider = FutureProvider.autoDispose.family<DrugRegistration?, String>(
  (ref, id) => ref.read(catalogueServiceProvider).registration(id),
);

// A registration's FDA check history, and whether it can be activated
final registrationChecksProvider = FutureProvider.autoDispose.family<List<VerificationCheck>, String>(
  (ref, id) => ref.read(catalogueServiceProvider).checks(id),
);
final registrationMatchProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.read(catalogueServiceProvider).hasMatch(id),
);