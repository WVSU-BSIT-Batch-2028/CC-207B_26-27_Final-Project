// F2 Marketplace: the details of one crop listing. Buyers can request to
// buy it, follow it, message the farmer, or open the farmer's profile. The
// page is live: the available amount changes as soon as stock is held.

import 'package:flutter/material.dart';

import '../models/followed_item.dart';
import '../models/listing.dart';
import '../models/assistant.dart';
import '../services/assistant_controller.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/ai_assistant_box.dart';
import '../widgets/crop_image.dart';
import '../widgets/follow_button.dart';
import '../widgets/info_row.dart';
import '../widgets/listing_card.dart';
import '../widgets/message_button.dart';
import '../widgets/page_header.dart';
import '../widgets/request_to_buy_sheet.dart';
import '../widgets/responsive_body.dart';
import '../widgets/stock_summary.dart';
import 'farmer_profile_screen.dart';

/// Shows everything about [listing].
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Listing?>(
      stream: ListingService().watch(listing.id),
      initialData: listing,
      builder: (context, snapshot) {
        final live = snapshot.data;
        if (live == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This crop listing was deleted.')),
          );
        }
        // Tells the AI assistant which listing is open.
        return AssistantScope(
          page: AssistantPage(AssistantScreen.listing, listing: live),
          child: _ListingDetails(listing: live),
        );
      },
    );
  }
}

class _ListingDetails extends StatelessWidget {
  const _ListingDetails({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser!;
    final isMine = listing.farmerId == me.id;
    final amount = '${formatQuantity(listing.available)} ${listing.unit}';
    final stock = listing.stockAt(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(listing.headline)),
      body: ResponsiveBody(
        maxWidth: AppSizes.maxFormWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            // Big sample photo with its credit, like the website. The note
            // makes clear it is not the farmer's own harvest.
            CropHero(
              crop: listing.crop,
              photoId: listing.photoId,
              note: 'The farmer has not added a photo.',
            ),
            const SizedBox(height: AppSizes.fieldGap),
            PageHeader(
              eyebrow: '${listing.town}, Iloilo',
              title: listing.headline,
              // With a title, the real crop is named right under it.
              lead: listing.title.isEmpty
                  ? '$amount available from ${listing.farmerName}.'
                  : '${listing.crop}: $amount available from '
                        '${listing.farmerName}.',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PriceText(
                  price: listing.price,
                  unit: listing.unit,
                  fontSize: 26,
                ),
                const SizedBox(width: AppSizes.small),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('asking price', style: AppTextStyles.meta),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Farmers see available / reserved / sold; buyers only what is
            // left (never who it is held for).
            StockSummary(listing: listing, forOwner: isMine),
            const SizedBox(height: 12),
            // Buyers get actions; a farmer looking at their own crop does not.
            if (!isMine && me.isBuyer) ...[
              FilledButton.icon(
                onPressed: stock == StockState.available && listing.isActive
                    ? () => showRequestToBuySheet(context, listing)
                    : null,
                icon: const Icon(Icons.shopping_basket_outlined),
                label: const Text('Request to buy'),
              ),
              if (stock != StockState.available || !listing.isActive) ...[
                const SizedBox(height: 4),
                Text(
                  stock == StockState.fullyReserved
                      ? 'All of it is held for other buyers right now. It '
                            'may come back if a buyer cancels.'
                      : 'This crop is sold out.',
                  style: AppTextStyles.meta,
                ),
              ],
              const SizedBox(height: AppSizes.small),
              MessageButton(
                otherId: listing.farmerId,
                otherName: listing.farmerName,
                label: 'Message farmer',
                firstMessage:
                    'Hi! Is your ${listing.crop} ($amount) still available?',
              ),
              const SizedBox(height: AppSizes.small),
              Row(
                children: [
                  Expanded(
                    child: FollowButton(
                      targetId: listing.id,
                      type: FollowType.listing,
                      title: '${listing.headline} · $amount',
                      subtitle:
                          '${formatPeso(listing.price)}/${listing.unit} · '
                          '${listing.farmerName}, ${listing.town}',
                    ),
                  ),
                  const SizedBox(width: AppSizes.small),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FarmerProfileScreen(farmerId: listing.farmerId),
                        ),
                      ),
                      icon: const Icon(Icons.person),
                      label: const Text('View farmer'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSizes.sectionGap),
            Card(
              child: Column(
                children: [
                  InfoRow(icon: Icons.eco, label: 'Crop', value: listing.crop),
                  InfoRow(icon: Icons.scale, label: 'Available', value: amount),
                  InfoRow(
                    icon: Icons.location_on,
                    label: 'Town',
                    value: '${listing.town}, Iloilo',
                  ),
                  InfoRow(
                    icon: Icons.event,
                    label: 'Harvest date',
                    value: listing.harvestDate == null
                        ? 'Not given'
                        : formatDate(listing.harvestDate!),
                  ),
                  InfoRow(
                    icon: Icons.person,
                    label: 'Farmer',
                    value: listing.farmerName,
                  ),
                  if (listing.description.isNotEmpty)
                    InfoRow(
                      icon: Icons.notes,
                      label: 'Description',
                      value: listing.description,
                    ),
                ],
              ),
            ),
            if (listing.aiAssisted) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: AiGeneratedChip(),
              ),
              const SizedBox(height: 4),
              const Text(
                'The farmer used the AI assistant to write this listing and '
                'checked it before posting.',
                style: AppTextStyles.meta,
              ),
            ],
            const SizedBox(height: AppSizes.sectionGap),
          ],
        ),
      ),
    );
  }
}
