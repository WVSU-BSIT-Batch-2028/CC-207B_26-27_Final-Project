// How a crop's price is labeled next to the number:
// - an amber "Older price" pill when its newest price is from before the
//   newest month in the list (so an old price never looks current),
// - otherwise ▲ / ▼ and the change since the month just before (green up,
//   red down, always with the arrow so color is not the only sign),
// - nothing when there is no price for the month just before.

import 'package:flutter/material.dart';

import '../utils/format.dart';
import '../utils/theme.dart';

/// The small label under a price.
class PriceChangeText extends StatelessWidget {
  const PriceChangeText({
    super.key,
    required this.change,
    required this.isOlder,
    this.fontSize = 13,
  });

  /// Change since the month just before, or null when unknown.
  final double? change;

  /// True when this crop's newest price is an older price.
  final bool isOlder;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (isOlder) return const OlderPriceTag();
    final value = change;
    if (value == null) return const SizedBox.shrink();
    final (text, color) = value == 0
        ? ('No change', AppColors.textMuted)
        : value > 0
        ? ('▲ ${formatPeso(value)}', AppColors.primaryDark)
        : ('▼ ${formatPeso(value.abs())}', AppColors.danger);
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

/// Amber "Older price" pill.
class OlderPriceTag extends StatelessWidget {
  const OlderPriceTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'PSA has no newer price for this crop yet.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Older price',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.warningInk,
          ),
        ),
      ),
    );
  }
}
