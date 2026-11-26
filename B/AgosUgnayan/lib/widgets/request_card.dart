// A card that shows one buyer request. Used in My Requests (buyer) and
// Buyer Demand (farmer). Looks like the website's request cards.

import 'package:flutter/material.dart';

import '../models/buyer_request.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'crop_thumb.dart';
import 'status_badge.dart';

/// Crop and amount, needed-by date, town, target price and an Open/Closed pill.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.trailing,
  });

  final BuyerRequest request;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final amount = '${formatQuantity(request.quantity)} ${request.unit}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CropThumb(crop: request.crop),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.crop}, $amount',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Needed by ${formatDate(request.neededBy)}'
                      '${_daysText(request)} · ${request.town}',
                      style: AppTextStyles.meta,
                    ),
                    // "Expires tomorrow" etc. on open requests due soon.
                    if (request.status == RequestStatus.open &&
                        request.daysLeft <= 3) ...[
                      const SizedBox(height: 4),
                      _DueSoonChip(daysLeft: request.daysLeft),
                    ],
                    if (request.targetPrice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Target ${formatPeso(request.targetPrice!)}/${request.unit}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.small),
              // Text, not just color, so the status is clear to everyone.
              RequestStatusBadge(request: request),
              // "?" adds trailing only when it is not null.
              ?trailing,
              if (trailing == null) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// " (3 days ago)" after the date of an expired request, else nothing.
String _daysText(BuyerRequest request) {
  if (request.status != RequestStatus.expired) return '';
  final ago = -request.daysLeft;
  return ' (${ago == 1 ? 'yesterday' : '$ago days ago'})';
}

/// The Open / Expired / Closed pill of a request (always with text).
class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge({super.key, required this.request});

  final BuyerRequest request;

  @override
  Widget build(BuildContext context) {
    return switch (request.status) {
      RequestStatus.open => const StatusBadge(
        label: 'Open',
        kind: StatusKind.open,
      ),
      RequestStatus.expired => const StatusBadge(
        label: 'Expired',
        kind: StatusKind.expired,
      ),
      RequestStatus.closed => const StatusBadge(
        label: 'Closed',
        kind: StatusKind.closed,
      ),
    };
  }
}

/// A small amber hint: "Expires today", "Expires tomorrow", "3 days left".
class _DueSoonChip extends StatelessWidget {
  const _DueSoonChip({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final text = switch (daysLeft) {
      0 => 'Expires today',
      1 => 'Expires tomorrow',
      _ => '$daysLeft days left',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: AppColors.warningInk),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.warningInk,
            ),
          ),
        ],
      ),
    );
  }
}
