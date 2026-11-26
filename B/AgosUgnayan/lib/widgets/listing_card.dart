// How one crop listing looks. ListingCard is a row for lists (My Crops, a
// farmer's profile); ListingGridCard is a tile for the Marketplace grid.
// Both match the website's crop rows and crop cards.

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'crop_thumb.dart';
import 'crop_image.dart';
import 'stock_summary.dart';

/// Crop, amount, town and farmer on the left, asking price on the right.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.trailing,
    this.showFarmer = true,
    this.showStock = false,
  });

  /// True in My Crops: shows available / reserved / sold and a bar.
  final bool showStock;

  final Listing listing;
  final VoidCallback onTap;

  /// Optional widget on the right, e.g. an Edit/Delete menu.
  final Widget? trailing;

  /// False on screens that are already about one farmer.
  final bool showFarmer;

  @override
  Widget build(BuildContext context) {
    final details = [
      // What buyers can still ask for (total minus held and sold). With the
      // stock line below, the amount is not repeated here.
      if (!showStock) '${formatQuantity(listing.available)} ${listing.unit}',
      listing.town,
      if (showFarmer) listing.farmerName,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                CropThumb(crop: listing.crop, photoId: listing.photoId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.headline,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      CropDetailsLine(listing: listing, details: details),
                      if (showStock) ...[
                        const SizedBox(height: 6),
                        StockSummary(listing: listing),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.small),
                PriceText(price: listing.price, unit: listing.unit),
                // "?" adds trailing only when it is not null.
                ?trailing,
                if (trailing == null) const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Marketplace tile: green photo area on top, crop and price below.
class ListingGridCard extends StatelessWidget {
  const ListingGridCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sample photo (or placeholder), 16:10 like the website's cards.
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CropImage(
                    crop: listing.crop,
                    size: CropImageSize.card,
                    photoId: listing.photoId,
                  ),
                  // "Only 3 kg left" etc. in the corner (empty when plenty).
                  Positioned(
                    right: 8,
                    top: 8,
                    child: StockChip(listing: listing),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.headline,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  CropDetailsLine(
                    listing: listing,
                    details:
                        '${formatQuantity(listing.available)} ${listing.unit} · '
                        '${listing.town}',
                  ),
                  Text(
                    listing.farmerName,
                    style: AppTextStyles.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  PriceText(
                    price: listing.price,
                    unit: listing.unit,
                    fontSize: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grey line under a listing's headline. When the listing has its own
/// title, the real crop name comes first in green, e.g.
/// "Pechay · 20 kg · Leon", so buyers always see which crop it is.
class CropDetailsLine extends StatelessWidget {
  const CropDetailsLine({
    super.key,
    required this.listing,
    required this.details,
  });

  final Listing listing;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          if (listing.title.isNotEmpty) ...[
            TextSpan(
              text: listing.crop,
              style: const TextStyle(
                color: AppColors.link,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: ' · '),
          ],
          TextSpan(text: details),
        ],
      ),
      style: AppTextStyles.meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A price in dark green with a small grey "/kg" after it, e.g. "₱45.00/kg".
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    required this.unit,
    this.fontSize = 17,
  });

  final double price;
  final String unit;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: formatPeso(price),
        style: AppTextStyles.price.copyWith(fontSize: fontSize),
        children: [
          TextSpan(
            text: '/$unit',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
