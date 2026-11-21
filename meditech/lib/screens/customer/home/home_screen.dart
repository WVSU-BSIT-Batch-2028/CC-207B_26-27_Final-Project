import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/pharmacy.dart';
import '../../../models/reservation.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../providers/reservation_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/pharmacy_card.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../shared/sign_in_sheet.dart';

// Main Flow home: guest browse stores, signed-in active reservations
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onSearchTap,
    this.onViewAllPharmaciesTap,
    this.onOpenReservations,
    this.onOpenReservationDetails,
    this.onOpenPharmacy,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onViewAllPharmaciesTap;
  final VoidCallback? onOpenReservations;
  final ValueChanged<String>? onOpenReservationDetails;
  final void Function(PharmacyDetail pharmacy)? onOpenPharmacy;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isGuest = session == null;
    final reservations = ref.watch(myReservationsProvider).value ?? const [];
    final active = reservations.where((r) => r.status.isActive).toList();
    final branchesAsync = ref.watch(publicBranchesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          _greeting,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Find medicine near you',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text(
              'La Paz, Iloilo City',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        InkWell(
          onTap: onSearchTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.textMuted),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Search medicine...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                  ),
                ),
                Icon(Icons.mic_none, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isGuest) ...[
          _GuestBanner(
            onSignIn: () => showCustomerSignInSheet(context),
            onCreateAccount: () => context.push('/sign-up'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else if (active.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Active reservations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenReservations,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...active.take(3).map(
            (reservation) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ActiveReservationCard(
                reservation: reservation,
                onTap: () => onOpenReservationDetails?.call(reservation.id),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Browse All Stores',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAllPharmaciesTap ?? onSearchTap,
              child: const Text('View maps'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Open now'),
                selected: false,
                onSelected: (_) => onViewAllPharmaciesTap?.call(),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChip(
                label: const Text('Sort By'),
                selected: false,
                onSelected: (_) => onViewAllPharmaciesTap?.call(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 320,
          child: AsyncView<List<PharmacyDetail>>(
            value: branchesAsync,
            isEmpty: (items) => items.isEmpty,
            emptyMessage: 'No approved pharmacies are listed yet.',
            onRetry: () => ref.invalidate(publicBranchesProvider),
            builder: (branches) {
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: branches.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  return PharmacyCard(
                    name: branch.pharmacyName,
                    branchName: branch.branchName,
                    address: branch.address,
                    distanceKm: branch.distanceKm,
                    isOpen: true,
                    onTap: () => onOpenPharmacy?.call(branch),
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

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({
    required this.onSignIn,
    required this.onCreateAccount,
  });

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "You're browsing as a guest",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You can search medicines, compare prices, and get directions. Sign in to reserve.',
            style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onSignIn,
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCreateAccount,
                  child: const Text('Create account'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveReservationCard extends StatelessWidget {
  const _ActiveReservationCard({
    required this.reservation,
    this.onTap,
  });

  final CustomerReservation reservation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (reservation.status) {
      ReservationStatus.readyForPickup => BadgeTone.success,
      ReservationStatus.confirmed => BadgeTone.info,
      _ => BadgeTone.warning,
    };
    final label = switch (reservation.status) {
      ReservationStatus.pending => 'Pending Confirmation',
      _ => reservation.status.label,
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.referenceNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reservation.pharmacyName,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StatusBadge(label, tone: tone),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
