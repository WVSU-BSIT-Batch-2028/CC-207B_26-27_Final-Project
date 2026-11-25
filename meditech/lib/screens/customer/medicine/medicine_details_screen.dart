import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/medicine.dart';
import '../../../providers/medicine_providers.dart';
import '../../../providers/cart_actions.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/branch_storefront_thumb.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/common/basket_bar.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../pharmacy/pharmacy_details_screen.dart';
import '../../../utils/public_media_urls.dart';
import '../../../widgets/common/medicine_card.dart';

// Filters the pharmacy list on the medicine screen. Null shows every offer.
class OfferAvailabilityFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? value) => state = value;
}

final offerAvailabilityFilterProvider =
    NotifierProvider<OfferAvailabilityFilter, String?>(
  OfferAvailabilityFilter.new,
);

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

  void _openPharmacy(BuildContext context, MedicineOffer offer) {
    final name = Uri.encodeComponent(offer.pharmacyName);
    if (GoRouter.maybeOf(context) != null) {
      context.push('/pharmacies/${offer.branchId}?name=$name');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PharmacyDetailsScreen(
          branchId: offer.branchId,
          initialTitle: offer.pharmacyName,
        ),
      ),
    );
  }

  void _openCart(BuildContext context) {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/cart');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(medicineSearchFilterProvider);
    final availabilityFilter = ref.watch(offerAvailabilityFilterProvider);
    final hasLocation = filter.latitude != null && filter.longitude != null;
    final offersAsync = ref.watch(medicineOffersProvider(medicine.medicineId));

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: CustomerLocationAppBarTitle(
          heading: medicine.brandName,
          icon: Icons.medication_outlined,
        ),
      ),
      bottomNavigationBar: CustomerBottomChrome(
        showBasket: true,
        onViewCart: () => _openCart(context),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOffline) const OfflineBanner(),
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
                        if (medicineImagePublicUrl(medicine.imagePath) != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.network(
                              medicineImagePublicUrl(medicine.imagePath)!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
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
                      '${medicine.strength} • ${medicine.dosageForm} • sold per ${medicine.unitSold}',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) => ref
                      .read(medicineOffersSortProvider.notifier)
                      .setSort(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'distance',
                      enabled: hasLocation,
                      child: Text(
                        hasLocation ? 'Nearest pharmacy' : 'Nearest (enable location)',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'updated',
                      child: Text('Recently updated'),
                    ),
                    const PopupMenuItem(
                      value: 'price',
                      child: Text('Lowest price'),
                    ),
                  ],
                  child: const _FilterLabel(
                    icon: Icons.sort,
                    label: 'Sort By',
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => ref
                      .read(offerAvailabilityFilterProvider.notifier)
                      .select(value == 'all' ? null : value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'all', child: Text('All')),
                    PopupMenuItem(value: 'available', child: Text('Available')),
                    PopupMenuItem(value: 'low_stock', child: Text('Low Stock')),
                    PopupMenuItem(
                      value: 'unavailable',
                      child: Text('Unavailable'),
                    ),
                  ],
                  child: const _FilterLabel(
                    icon: Icons.tune,
                    label: 'Availability Status',
                  ),
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
                final visible = [
                  for (final offer in offers)
                    if (_matchesAvailability(offer, availabilityFilter)) offer,
                ];
                if (visible.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No pharmacies currently list this medicine.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    customerBottomChromeScrollPadding(
                      context,
                      showBasket: true,
                    ),
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final offer = visible[index];
                    return _MedicineOfferCard(
                      medicine: medicine,
                      offer: offer,
                      onOpenPharmacy: () => _openPharmacy(context, offer),
                      onOpenStore: () => _openPharmacy(context, offer),
                      onAddToCart: offer.availability.canReserve
                          ? () {
                              if (onAddToCart != null) {
                                onAddToCart!(medicine, offer);
                                return;
                              }
                              addMedicineToCartWithBranchCheck(
                                context: context,
                                ref: ref,
                                branchId: offer.branchId,
                                medicineId: medicine.medicineId,
                                medicineName: medicine.brandName,
                                pharmacyName: offer.pharmacyName,
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

bool _matchesAvailability(MedicineOffer offer, String? filter) {
  return switch (filter) {
    null => true,
    'available' => offer.availability == MedicineAvailability.available,
    'low_stock' => offer.availability == MedicineAvailability.lowStock,
    'unavailable' => offer.availability == MedicineAvailability.unavailable,
    _ => true,
  };
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
      ],
    );
  }
}

class _MedicineOfferCard extends StatelessWidget {
  const _MedicineOfferCard({
    required this.medicine,
    required this.offer,
    required this.onOpenPharmacy,
    required this.onOpenStore,
    this.onAddToCart,
  });

  final MedicineSearchResult medicine;
  final MedicineOffer offer;
  final VoidCallback onOpenPharmacy;
  final VoidCallback onOpenStore;
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
                  BranchStorefrontThumb(
                    branchId: offer.branchId,
                    size: 48,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.pharmacyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          offer.branchName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          offer.distanceKm == null
                              ? offer.address
                              : '${offer.address} • ${offer.distanceKm!.toStringAsFixed(1)} km',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const StatusBadge(
                          'Registered on MediTech',
                          tone: BadgeTone.success,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open ${offer.pharmacyName}',
                    onPressed: onOpenStore,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${medicine.brandName} (${medicine.genericName})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    '₱${offer.pricePerUnit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  StatusBadge.availability(
                    offer.availability.name == 'lowStock'
                        ? 'low_stock'
                        : offer.availability.name,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Updated ${stockUpdatedAgo(offer.stockConfirmedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: onAddToCart == null ? 'Unavailable' : 'Add to Cart',
                    onPressed: onAddToCart,
                    style: IconButton.styleFrom(
                      backgroundColor: onAddToCart == null
                          ? AppColors.neutralLight
                          : AppColors.primary,
                      foregroundColor: onAddToCart == null
                          ? AppColors.textMuted
                          : Colors.white,
                      disabledBackgroundColor: AppColors.neutralLight,
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.add, size: 20),
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
