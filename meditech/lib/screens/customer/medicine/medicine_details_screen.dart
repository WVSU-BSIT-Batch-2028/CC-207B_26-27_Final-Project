import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/medicine.dart';
import '../../../providers/medicine_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../pharmacy/pharmacy_details_screen.dart';

// Customer medicine details screen matching wireframe P-11
class MedicineDetailsScreen extends ConsumerWidget {
  const MedicineDetailsScreen({
    super.key,
    required this.medicine,
    this.isOffline = false,
    this.onAddToCart,
  });

  final MedicineSearchResult medicine;
  final bool isOffline;

  // Optional callback when customer taps Add to Cart on an available offer
  final void Function(MedicineSearchResult medicine, MedicineOffer offer)?
      onAddToCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(medicineOffersSortProvider);
    final filter = ref.watch(medicineSearchFilterProvider);
    final hasLocation = filter.latitude != null && filter.longitude != null;
    final offersAsync = ref.watch(medicineOffersProvider(medicine.medicineId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Details'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOffline) const OfflineBanner(),
          // Medicine summary card
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.brandName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                medicine.genericName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (medicine.isRx) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const StatusBadge.rx(),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${medicine.strength} · ${medicine.dosageForm} · Sold per ${medicine.unitSold}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (medicine.isRx) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.info,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Prescription required at pickup.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Pharmacy offers header + Price / Distance sort chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available at pharmacies',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Row(
                  children: [
                    AppChip(
                      label: 'Lowest price',
                      selected: sort == 'price',
                      onSelected: (_) => ref
                          .read(medicineOffersSortProvider.notifier)
                          .setSort('price'),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(width: AppSpacing.xs),
                      AppChip(
                        label: 'Nearest',
                        selected: sort == 'distance',
                        onSelected: (_) => ref
                            .read(medicineOffersSortProvider.notifier)
                            .setSort('distance'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Pharmacy offer cards
          Expanded(
            child: AsyncView<List<MedicineOffer>>(
              value: offersAsync,
              isEmpty: (offers) => offers.isEmpty,
              emptyMessage: 'No pharmacies currently list this medicine.',
              onRetry: () =>
                  ref.invalidate(medicineOffersProvider(medicine.medicineId)),
              builder: (offers) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: offers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    return _MedicineOfferCard(
                      medicine: medicine,
                      offer: offer,
                      onOpenPharmacy: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PharmacyDetailsScreen(
                              branchId: offer.branchId,
                              initialTitle: offer.pharmacyName,
                            ),
                          ),
                        );
                      },
                      onAddToCart: offer.availability.canReserve
                          ? () {
                              if (onAddToCart != null) {
                                onAddToCart!(medicine, offer);
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added ${medicine.brandName} from ${offer.pharmacyName}.',
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineOfferCard extends StatelessWidget {
  const _MedicineOfferCard({
    required this.medicine,
    required this.offer,
    required this.onOpenPharmacy,
    this.onAddToCart,
  });

  final MedicineSearchResult medicine;
  final MedicineOffer offer;
  final VoidCallback onOpenPharmacy;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenPharmacy,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.pharmacyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          offer.branchName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.availability(offer.availability.name == 'lowStock'
                      ? 'low_stock'
                      : offer.availability.name),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      offer.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (offer.distanceKm != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${offer.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱${offer.pricePerUnit.toStringAsFixed(2)} / ${medicine.unitSold}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  FilledButton(
                    onPressed: onAddToCart,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(116, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    child: Text(
                      offer.availability.canReserve
                          ? 'Add to Cart'
                          : 'Unavailable',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}