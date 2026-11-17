import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/session_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/medicine_card.dart';
import '../../../widgets/common/pharmacy_card.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../shared/sign_in_sheet.dart';

// Home screen showing search, categories, guest prompt, and featured items
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onSearchTap,
    this.onViewAllPharmaciesTap,
  });

  final VoidCallback? onSearchTap;

  final VoidCallback? onViewAllPharmaciesTap;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'All';

  final _categories = const [
    'All',
    'Prescription',
    'Over-the-counter',
    'Vitamins',
    'First Aid',
  ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isGuest = session == null;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        // Search bar tap target
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: InkWell(
            onTap: widget.onSearchTap,
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
                  Text(
                    'Search medicines or pharmacies...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppChip(
                  label: category,
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = category);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Guest prompt card shown only when not signed in
        if (isGuest) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Card(
              color: AppColors.primaryLight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order ahead for faster pickup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Sign in to reserve medicines, track orders, and upload prescriptions.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => showCustomerSignInSheet(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 40),
                      ),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Available medicines section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available medicines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              TextButton(
                onPressed: widget.onSearchTap,
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              MedicineCard(
                name: 'Biogesic',
                genericName: 'Paracetamol',
                strength: '500 mg',
                dosageForm: 'Tablet',
                availability: 'available',
                priceText: '₱5.50',
                pharmacyCount: 2,
                onTap: widget.onSearchTap,
              ),
              const SizedBox(height: AppSpacing.sm),
              MedicineCard(
                name: 'Amoxil',
                genericName: 'Amoxicillin',
                strength: '500 mg',
                dosageForm: 'Capsule',
                availability: 'available',
                requiresPrescription: true,
                priceText: '₱12.00',
                pharmacyCount: 2,
                onTap: widget.onSearchTap,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Nearby pharmacies section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby pharmacies',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              TextButton(
                onPressed: widget.onViewAllPharmaciesTap ?? widget.onSearchTap,
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              PharmacyCard(
                name: 'Demo Pharmacy',
                branchName: 'La Paz Branch',
                address: 'Huervana St, La Paz, Iloilo City',
                distanceKm: 0.8,
                isOpen: true,
                onTap: widget.onViewAllPharmaciesTap,
              ),
              const SizedBox(height: AppSpacing.sm),
              PharmacyCard(
                name: 'Demo Pharmacy',
                branchName: 'Jaro Branch',
                address: 'E. Lopez St, Jaro, Iloilo City',
                distanceKm: 2.1,
                isOpen: true,
                onTap: widget.onViewAllPharmaciesTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}