// A farmer's public profile: name, town, and all their crops for sale.
// Buyers can follow the farmer or message them from here.

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/followed_item.dart';
import '../models/listing.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../utils/app_exception.dart';
import '../utils/theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/follow_button.dart';
import '../widgets/listing_card.dart';
import '../widgets/message_button.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_body.dart';
import 'listing_detail_screen.dart';

/// Loads and shows the farmer with id [farmerId].
class FarmerProfileScreen extends StatefulWidget {
  const FarmerProfileScreen({super.key, required this.farmerId});

  final String farmerId;

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  AppUser? _farmer;
  List<Listing> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Load the profile and the listings at the same time.
      final results = await Future.wait([
        AuthService().loadOtherUser(widget.farmerId),
        ListingService().fetchByFarmer(widget.farmerId),
      ]);
      if (!mounted) return;
      setState(() {
        _farmer = results[0] as AppUser;
        // Buyers only see crops that are still for sale.
        _listings = (results[1] as List<Listing>)
            .where((l) => l.isActive)
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer')),
      body: AsyncStateView(
        isLoading: _isLoading,
        errorMessage: _error,
        onRetry: _load,
        isEmpty: _farmer == null,
        emptyMessage: 'This farmer was not found.',
        builder: (context) => _buildProfile(_farmer!),
      ),
    );
  }

  Widget _buildProfile(AppUser farmer) {
    final isBuyer = AuthService.currentUser!.isBuyer;
    return ResponsiveBody(
      maxWidth: AppSizes.maxFormWidth,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          // Big avatar with the first letter, then name and town.
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  farmer.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PageHeader(
                  eyebrow: 'Farmer',
                  title: farmer.name,
                  lead: '${farmer.town}, Iloilo',
                ),
              ),
            ],
          ),
          if (farmer.about.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(farmer.about, style: const TextStyle(fontSize: 15)),
          ],
          const SizedBox(height: AppSizes.fieldGap),
          if (isBuyer) ...[
            MessageButton(
              otherId: farmer.id,
              otherName: farmer.name,
              label: 'Message ${farmer.name}',
            ),
            const SizedBox(height: AppSizes.small),
            FollowButton(
              targetId: farmer.id,
              type: FollowType.farmer,
              title: farmer.name,
              subtitle: 'Farmer · ${farmer.town}',
            ),
          ],
          const SizedBox(height: AppSizes.sectionGap),
          SectionTitle('Crops for sale (${_listings.length})'),
          const SizedBox(height: AppSizes.small),
          if (_listings.isEmpty)
            const Text(
              'No crops for sale right now.',
              style: AppTextStyles.lead,
            ),
          for (final listing in _listings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.small),
              child: ListingCard(
                listing: listing,
                showFarmer: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: listing),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
