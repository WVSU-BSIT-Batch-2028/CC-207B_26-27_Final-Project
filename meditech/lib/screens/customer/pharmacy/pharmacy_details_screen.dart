import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/pharmacy.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../providers/cart_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/medicine_card.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'directions_screen.dart';

// Customer pharmacy branch details screen matching wireframe P-12
class PharmacyDetailsScreen extends ConsumerStatefulWidget {
  const PharmacyDetailsScreen({
    super.key,
    required this.branchId,
    this.initialTitle,
    this.isOffline = false,
    this.onAddInventoryItem,
  });

  final String branchId;
  final String? initialTitle;
  final bool isOffline;
  final void Function(PharmacyDetail branch, PharmacyInventoryItem item)?
  onAddInventoryItem;

  @override
  ConsumerState<PharmacyDetailsScreen> createState() =>
      _PharmacyDetailsScreenState();
}

class _PharmacyDetailsScreenState extends ConsumerState<PharmacyDetailsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(pharmacyInventoryQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(pharmacyInventoryQueryProvider.notifier).setQuery(value);
    });
  }

  String _availabilityCode(PharmacyInventoryItem item) {
    return item.availability.name == 'lowStock'
        ? 'low_stock'
        : item.availability.name;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(pharmacyDetailProvider(widget.branchId));
    final hoursAsync = ref.watch(pharmacyHoursProvider(widget.branchId));
    final inventoryAsync = ref.watch(
      pharmacyInventoryProvider(widget.branchId),
    );

    final title =
        detailAsync.value?.pharmacyName ??
        widget.initialTitle ??
        'Pharmacy Details';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isOffline) const OfflineBanner(),
          Expanded(
            child: AsyncView<PharmacyDetail?>(
              value: detailAsync,
              isEmpty: (branch) => branch == null,
              emptyMessage: 'This pharmacy is currently unavailable.',
              onRetry: () =>
                  ref.invalidate(pharmacyDetailProvider(widget.branchId)),
              builder: (branch) {
                final pharmacy = branch!;
                final hours = hoursAsync.value ?? const <PharmacyHours>[];

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Branch header card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacy.pharmacyName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pharmacy.branchName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    pharmacy.address,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  pharmacy.contactNumber,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DirectionsScreen(
                                        pharmacyName: pharmacy.pharmacyName,
                                        branchName: pharmacy.branchName,
                                        address: pharmacy.address,
                                        destination: LatLng(
                                          pharmacy.latitude,
                                          pharmacy.longitude,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.directions_outlined),
                                label: const Text('Get directions'),
                              ),
                            ),
                            if (hours.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Divider(),
                              ),
                              const Text(
                                'Opening hours',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ...hours.map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        row.dayLabel,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        row.scheduleLabel,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: row.isClosed
                                              ? AppColors.danger
                                              : AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Available medicines',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _searchController,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        hintText: 'Search in ${pharmacy.pharmacyName}',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _debounce?.cancel();
                                  _searchController.clear();
                                  setState(() {});
                                  ref
                                      .read(
                                        pharmacyInventoryQueryProvider.notifier,
                                      )
                                      .setQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView<List<PharmacyInventoryItem>>(
                      value: inventoryAsync,
                      isEmpty: (items) => items.isEmpty,
                      emptyMessage: 'No matching medicines in this branch.',
                      onRetry: () => ref.invalidate(
                        pharmacyInventoryProvider(widget.branchId),
                      ),
                      builder: (items) {
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return MedicineCard(
                              name: item.brandName,
                              genericName: item.genericName,
                              strength: item.strength,
                              dosageForm: item.dosageForm,
                              requiresPrescription: item.isRx,
                              availability: _availabilityCode(item),
                              priceText: item.formattedPrice,
                              onTap: item.availability.canReserve
                                  ? () {
                                      if (widget.onAddInventoryItem != null) {
                                        widget.onAddInventoryItem!(
                                          pharmacy,
                                          item,
                                        );
                                        return;
                                      }
                                      addMedicineToCartWithBranchCheck(
                                        context: context,
                                        ref: ref,
                                        branchId: pharmacy.branchId,
                                        medicineId: item.medicineId,
                                        medicineName: item.brandName,
                                        pharmacyName: pharmacy.pharmacyName,
                                      );
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                    ),
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
