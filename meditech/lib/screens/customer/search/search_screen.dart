import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/medicine.dart';
import '../../../providers/medicine_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/customer_location_title.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

import '../medicine/medicine_details_screen.dart';

// Customer medicine search screen matching wireframes P-09 and P-10

class RecentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    state = [
      trimmed,
      for (final item in state)
        if (item.toLowerCase() != trimmed.toLowerCase()) item,
    ].take(8).toList();
  }

  void clear() => state = const [];
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.isOffline = false,
    this.onMedicineSelected,
    this.onBack,
  });

  // Shows the offline banner when true
  final bool isOffline;

  // Called when a customer taps a medicine result card
  final ValueChanged<MedicineSearchResult>? onMedicineSelected;

  // Shell uses this to return to the home tab
  final VoidCallback? onBack;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(medicineSearchFilterProvider).query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Debounces typing so Supabase isn't queried on every single keystroke
  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(medicineSearchFilterProvider.notifier).setQuery(value);
    });
  }

  void _remember(String term) {
    ref.read(recentSearchesProvider.notifier).add(term);
  }

  void _openMedicine(MedicineSearchResult med) {
    _remember(med.brandName);
    if (widget.onMedicineSelected != null) {
      widget.onMedicineSelected!(med);
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push('/medicines', extra: med);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineDetailsScreen(medicine: med),
      ),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(medicineSearchFilterProvider.notifier).setQuery('');
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'price':
        return 'Sort: Price';
      case 'distance':
        return 'Sort: Distance';
      case 'relevance':
      default:
        return 'Sort: Relevance';
    }
  }

  // Opens the sort bottom sheet (Relevance, Price, Distance)
  Future<void> _openSortSheet() async {
    final filter = ref.read(medicineSearchFilterProvider);
    final hasLocation = filter.latitude != null && filter.longitude != null;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        String selected = filter.sort;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selected = val);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RadioListTile<String>(
                          value: 'relevance',
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Relevance'),
                        ),
                        const RadioListTile<String>(
                          value: 'price',
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Lowest price'),
                        ),
                        RadioListTile<String>(
                          value: 'distance',
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          enabled: hasLocation,
                          title: Text(
                            hasLocation
                                ? 'Nearest pharmacy'
                                : 'Nearest pharmacy (enable location)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(medicineSearchFilterProvider.notifier)
                          .setSort(selected);
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Opens the strength and location filter bottom sheet
  Future<void> _openFilterSheet() async {
    final current = ref.read(medicineSearchFilterProvider);
    final strengthController = TextEditingController(text: current.strength);
    final locationController = TextEditingController(text: current.location);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter medicines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      strengthController.clear();
                      locationController.clear();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Strength',
                controller: strengthController,
                hint: 'e.g. 500 mg',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Pharmacy location',
                controller: locationController,
                hint: 'e.g. La Paz, Jaro, Molo',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final notifier = ref.read(
                    medicineSearchFilterProvider.notifier,
                  );
                  notifier.setStrength(strengthController.text);
                  notifier.setLocation(locationController.text);
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Show results'),
              ),
            ],
          ),
        );
      },
    );

    strengthController.dispose();
    locationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(medicineSearchFilterProvider);
    final resultsAsync = ref.watch(medicineSearchResultsProvider);
    final recent = ref.watch(recentSearchesProvider);

    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isOffline) const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: CustomerLocationTitle(
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _remember,
              decoration: InputDecoration(
                hintText: 'Search medicine...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearSearch,
                      ),
                    IconButton(
                      tooltip: _sortLabel(filter.sort),
                      icon: const Icon(Icons.swap_vert),
                      onPressed: _openSortSheet,
                    ),
                    IconButton(
                      tooltip: filter.activeExtraFilterCount > 0
                          ? 'Filters (${filter.activeExtraFilterCount})'
                          : 'Filters',
                      icon: const Icon(Icons.tune),
                      onPressed: _openFilterSheet,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: AsyncView<List<MedicineSearchResult>>(
              value: resultsAsync,
              isEmpty: (items) => items.isEmpty && recent.isEmpty,
              emptyMessage: 'No matching medicines found.',
              onRetry: () => ref.invalidate(medicineSearchResultsProvider),
              builder: (items) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    120,
                  ),
                  children: [
                    if (recent.isNotEmpty) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Recent Searches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.read(recentSearchesProvider.notifier).clear(),
                            child: const Text('Clear all'),
                          ),
                        ],
                      ),
                      ...recent.map(
                        (term) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.history,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          title: Text(term),
                          onTap: () {
                            _searchController.text = term;
                            _onQueryChanged(term);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const Text(
                      'In Stock at Nearby Pharmacies',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppChip(
                          label: 'All',
                          selected: filter.dosageForm == null,
                          onSelected: (_) => ref
                              .read(medicineSearchFilterProvider.notifier)
                              .setDosageForm(null),
                        ),
                        for (final form
                            in ref.watch(dosageFormsProvider).value ??
                                const <String>[])
                          AppChip(
                            label: form,
                            selected: filter.dosageForm == form,
                            onSelected: (_) => ref
                                .read(medicineSearchFilterProvider.notifier)
                                .setDosageForm(
                                  filter.dosageForm == form ? null : form,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          'No matching medicines found.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    else
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        _StockMedicineCard(
                          medicine: items[i],
                          onTap: () => _openMedicine(items[i]),
                        ),
                      ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockMedicineCard extends StatelessWidget {
  const _StockMedicineCard({required this.medicine, required this.onTap});

  final MedicineSearchResult medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.primaryLight,
                  child: const Icon(Icons.medication, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.brandName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          medicine.genericName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' • ${medicine.strength} • ${medicine.dosageForm}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          medicine.formattedLowestPrice,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' • ${medicine.pharmacyCount} ${medicine.pharmacyCount == 1 ? 'pharmacy' : 'pharmacies'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (medicine.pharmacyCount > 0)
                          StatusBadge.availability('available'),
                        if (medicine.isRx)
                          const StatusBadge(
                            'Rx required',
                            tone: BadgeTone.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Results list with loading, empty (P-10), and error states
        Expanded(
          child: AsyncView<List<MedicineSearchResult>>(
            value: resultsAsync,
            isEmpty: (items) => items.isEmpty,
            emptyMessage: 'No matching medicines found.',
            onRetry: () => ref.invalidate(medicineSearchResultsProvider),
            builder: (items) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  120,
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: 'View ${medicine.brandName}',
                onPressed: onTap,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
