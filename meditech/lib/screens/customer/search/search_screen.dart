import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/medicine.dart';
import '../../../providers/medicine_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/medicine_card.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

import '../medicine/medicine_details_screen.dart';

// Customer medicine search screen matching wireframes P-09 and P-10
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.isOffline = false,
    this.onMedicineSelected,
  });

  // Shows the offline banner when true
  final bool isOffline;

  // Called when a customer taps a medicine result card
  final ValueChanged<MedicineSearchResult>? onMedicineSelected;

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
    final formsAsync = ref.watch(dosageFormsProvider);
    final dosageForms = formsAsync.value ?? const ['Tablet', 'Capsule'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isOffline) const OfflineBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Search input matching wireframe P-09
              TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Try paracetamol or Biogesic',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Horizontal filter chips + Sort & More Filters chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppChip(
                      label: 'All',
                      selected: filter.dosageForm == null,
                      onSelected: (_) => ref
                          .read(medicineSearchFilterProvider.notifier)
                          .setDosageForm(null),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ...dosageForms.map(
                      (form) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppChip(
                          label: form,
                          selected: filter.dosageForm == form,
                          onSelected: (_) => ref
                              .read(medicineSearchFilterProvider.notifier)
                              .setDosageForm(
                                filter.dosageForm == form ? null : form,
                              ),
                        ),
                      ),
                    ),
                    AppChip(
                      label: _sortLabel(filter.sort),
                      icon: Icons.swap_vert,
                      selected: filter.sort != 'relevance',
                      onSelected: (_) => _openSortSheet(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppChip(
                      label: filter.activeExtraFilterCount > 0
                          ? 'Filters (${filter.activeExtraFilterCount})'
                          : 'Filters',
                      icon: Icons.tune,
                      selected: filter.activeExtraFilterCount > 0,
                      onSelected: (_) => _openFilterSheet(),
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
                  AppSpacing.lg,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final med = items[index];
                  return MedicineCard(
                    name: med.brandName,
                    genericName: med.genericName,
                    strength: med.strength,
                    dosageForm: med.dosageForm,
                    requiresPrescription: med.isRx,
                    pharmacyCount: med.pharmacyCount,
                    priceText: med.formattedLowestPrice,
                    onTap: () {
                      if (widget.onMedicineSelected != null) {
                        widget.onMedicineSelected!(med);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MedicineDetailsScreen(medicine: med),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
