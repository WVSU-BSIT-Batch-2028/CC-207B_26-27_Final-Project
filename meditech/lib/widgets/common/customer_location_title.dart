import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/customer_location_provider.dart';

// Shown until the device shares a location
const customerAreaLabel = '6 Jaro St, La Paz, Iloilo City';

// Header place name: the device address when location is allowed
class CustomerLocationTitle extends ConsumerWidget {
  const CustomerLocationTitle({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(customerLocationProvider).value;
    final label = place?.label;
    return Text(
      (label == null || label.isEmpty) ? customerAreaLabel : label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
