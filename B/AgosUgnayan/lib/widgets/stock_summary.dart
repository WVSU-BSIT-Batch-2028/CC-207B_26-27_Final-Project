// How much of a listing is available, reserved and sold. Farmers see all
// three numbers and a small bar; buyers see only what is left (never who
// the rest is held for). StockChip is the short label used on cards.

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../utils/format.dart';
import '../utils/theme.dart';

/// True when little is left: at most a fifth of the total stock.
bool isLowStock(Listing listing, DateTime now) {
  final left = listing.availableAt(now);
  return left > 0 && left <= listing.quantity * 0.2;
}

/// "15 kg available · 5 kg reserved · 0 kg sold" with a bar (farmer), or
/// "15 kg available" (buyer).
class StockSummary extends StatelessWidget {
  const StockSummary({super.key, required this.listing, this.forOwner = true});

  final Listing listing;
  final bool forOwner;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final unit = listing.unit;
    final available = listing.availableAt(now);
    final reserved = listing.reservedAt(now);
    final sold = listing.soldQty;
    String kg(double value) => '${formatQuantity(value)} $unit';

    if (!forOwner) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${kg(available)} available',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          StockChip(listing: listing),
        ],
      );
    }

    final total = listing.quantity <= 0 ? 1.0 : listing.quantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${kg(available)} available · ${formatQuantity(reserved)} '
          'reserved · ${formatQuantity(sold)} sold',
          style: AppTextStyles.meta,
          maxLines: 2, // wraps on phones instead of being cut off
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Green = sold, light green = reserved, grey = still available.
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              // Stretch, or the empty colored parts would be 0 px tall.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _part(sold / total, AppColors.primary),
                _part(reserved / total, AppColors.link.withValues(alpha: 0.45)),
                _part(available / total, AppColors.segmented),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _part(double fraction, Color color) {
    final flex = (fraction.clamp(0, 1) * 1000).round();
    if (flex == 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: ColoredBox(color: color),
    );
  }
}

/// "Only 3 kg left", "Fully reserved" or "Sold out" (nothing when plenty
/// is left). Always words, never only a color.
class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final state = listing.stockAt(now);
    final String label;
    if (state == StockState.soldOut) {
      label = 'Sold out';
    } else if (state == StockState.fullyReserved) {
      label = 'Fully reserved';
    } else if (isLowStock(listing, now)) {
      label =
          'Only ${formatQuantity(listing.availableAt(now))} '
          '${listing.unit} left';
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.warningInk,
        ),
      ),
    );
  }
}
