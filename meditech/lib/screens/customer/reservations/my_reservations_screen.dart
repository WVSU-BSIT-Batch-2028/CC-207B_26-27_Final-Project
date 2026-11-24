import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/reservation.dart';
import '../../../providers/reservation_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'reservation_details_screen.dart';

// Filter tabs matching wireframes P-24 and P-25
enum ReservationFilterTab {
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled'),
  rejected('Rejected'),
  expired('Expired');

  const ReservationFilterTab(this.label);

  final String label;

  bool matches(ReservationStatus status) {
    switch (this) {
      case ReservationFilterTab.active:
        return status.isActive;
      case ReservationFilterTab.completed:
        return status == ReservationStatus.completed;
      case ReservationFilterTab.cancelled:
        return status == ReservationStatus.cancelled;
      case ReservationFilterTab.rejected:
        return status == ReservationStatus.rejected;
      case ReservationFilterTab.expired:
        return status == ReservationStatus.expired;
    }
  }
}

class MyReservationsScreen extends ConsumerStatefulWidget {
  const MyReservationsScreen({
    super.key,
    this.isOffline = false,
    this.onBrowseMedicines,
  });

  final bool isOffline;
  final VoidCallback? onBrowseMedicines;

  @override
  ConsumerState<MyReservationsScreen> createState() =>
      _MyReservationsScreenState();
}

class _MyReservationsScreenState extends ConsumerState<MyReservationsScreen> {
  ReservationFilterTab _selectedTab = ReservationFilterTab.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(myReservationsProvider.notifier).refresh();
      }
    });
  }

  void _openDetails(String reservationId) {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/reservations/$reservationId');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReservationDetailsScreen(reservationId: reservationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(myReservationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isOffline) const OfflineBanner(),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: CustomerLocationAppBarTitle(
            heading: 'My Reservations',
            icon: Icons.receipt_long_outlined,
          ),
        ),
        // Status filter chips bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: ReservationFilterTab.values.map((tab) {
              final selected = tab == _selectedTab;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(tab.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTab = tab),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: AsyncView<List<CustomerReservation>>(
            value: reservationsAsync,
            onRetry: () => ref.read(myReservationsProvider.notifier).refresh(),
            builder: (allReservations) {
              final filtered = allReservations
                  .where((r) => _selectedTab.matches(r.status))
                  .toList();

              if (filtered.isEmpty) {
                return _EmptyTabView(
                  tab: _selectedTab,
                  onBrowseMedicines: widget.onBrowseMedicines,
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(myReservationsProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final reservation = filtered[index];
                    return _ReservationCard(
                      reservation: reservation,
                      onTap: () => _openDetails(reservation.id),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onTap,
  });

  final CustomerReservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'MMM d, yyyy · h:mm a',
    ).format(reservation.submittedAt.toLocal());
    final pickupCode = reservation.fullPickupCode;
    final showPickupCode =
        reservation.status == ReservationStatus.readyForPickup &&
        pickupCode != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    reservation.referenceNo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  StatusBadge.reservation(reservation.status.dbValue),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                reservation.branchName.isNotEmpty
                    ? '${reservation.pharmacyName} · ${reservation.branchName}'
                    : reservation.pharmacyName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reservation.medicinesSummary,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.text,
                ),
              ),
              if (showPickupCode) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_2_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pickup Code: $pickupCode',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if ((reservation.status == ReservationStatus.rejected ||
                      reservation.status == ReservationStatus.cancelled) &&
                  (reservation.closedReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Reason: ${reservation.closedReason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    reservation.formattedTotal,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
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

class _EmptyTabView extends StatelessWidget {
  const _EmptyTabView({
    required this.tab,
    this.onBrowseMedicines,
  });

  final ReservationFilterTab tab;
  final VoidCallback? onBrowseMedicines;

  @override
  Widget build(BuildContext context) {
    final isActiveTab = tab == ReservationFilterTab.active;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isActiveTab
                  ? 'No active reservations'
                  : 'No ${tab.label.toLowerCase()} reservations',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isActiveTab
                  ? 'Search for medicines and place a reservation at a nearby pharmacy.'
                  : 'Reservations with ${tab.label.toLowerCase()} status will appear here.',
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            if (isActiveTab && onBrowseMedicines != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onBrowseMedicines,
                child: const Text('Browse Medicines'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}