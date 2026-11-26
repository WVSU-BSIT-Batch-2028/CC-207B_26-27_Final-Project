// One message in the buyer assistant's chat. The AI's words carry an
// "AI suggestion" label; the numbers from the app are shown apart, in a
// "Facts from AgosUgnayan" box, and search results are real listings the
// buyer can open. Nothing here buys or changes anything.

import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../models/listing.dart';
import '../screens/listing_detail_screen.dart';
import '../services/assistant_controller.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'crop_thumb.dart';
import 'home_nav.dart';

class AssistantMessageView extends StatelessWidget {
  const AssistantMessageView({
    super.key,
    required this.message,
    required this.controller,
  });

  final AssistantMessage message;
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    if (message.isBuyer) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message.text),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Label(isFallback: message.isFallback, fromApp: message.fromApp),
              // General knowledge is marked, so nobody takes it for app data.
              if (message.isGeneral) const _GeneralTag(),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.text, style: const TextStyle(fontSize: 14)),
          if (message.facts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FactsBox(rows: message.facts),
          ],
          for (final listing in message.listings)
            _ListingResult(listing: listing, controller: controller),
          // "Try asking:" chips after "I can't help with that".
          if (message.suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final chip in message.suggestions)
                    ActionChip(
                      label: Text(
                        chip.text,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: controller.isThinking
                          ? null
                          : () =>
                                controller.ask(chip.text, intent: chip.intent),
                    ),
                ],
              ),
            ),
          if (message.marketCrop != null)
            TextButton.icon(
              onPressed: () => controller.openTab(HomeTab.market),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Open the Market'),
            ),
        ],
      ),
    );
  }
}

/// "AI suggestion"; "From AgosUgnayan" when the app answered by itself;
/// "Facts only (no AI)" when the AI was busy.
class _Label extends StatelessWidget {
  const _Label({required this.isFallback, required this.fromApp});

  final bool isFallback;
  final bool fromApp;

  @override
  Widget build(BuildContext context) {
    if (fromApp) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'From AgosUgnayan',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFallback ? AppColors.segmented : AppColors.infoLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isFallback ? 'Facts only (no AI)' : 'AI suggestion',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isFallback ? AppColors.textMuted : AppColors.info,
        ),
      ),
    );
  }
}

/// "General answer, not from AgosUgnayan data".
class _GeneralTag extends StatelessWidget {
  const _GeneralTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'General answer, not from AgosUgnayan data',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.warningInk,
        ),
      ),
    );
  }
}

/// The app's own numbers, shown apart from the AI's words.
class _FactsBox extends StatelessWidget {
  const _FactsBox({required this.rows});

  final List<FactRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Facts from AgosUgnayan',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(row.label, style: AppTextStyles.meta),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A real listing from the search, like a small Market card.
class _ListingResult extends StatelessWidget {
  const _ListingResult({required this.listing, required this.controller});

  final Listing listing;
  final AssistantController controller;

  void _open() {
    controller.close();
    AssistantController.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = listing.unit;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CropThumb(crop: listing.crop, photoId: listing.photoId),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.headline,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${listing.crop} · ${formatPeso(listing.price)}/$unit',
                      style: AppTextStyles.meta,
                    ),
                    Text(
                      '${formatQuantity(listing.available)} $unit available · '
                      '${listing.farmerName}, ${listing.town}',
                      style: AppTextStyles.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _open, child: const Text('Open')),
            ],
          ),
        ),
      ),
    );
  }
}
