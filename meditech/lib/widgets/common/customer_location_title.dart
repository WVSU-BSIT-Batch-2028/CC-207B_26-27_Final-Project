import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/customer_location_provider.dart';

const customerLocationOffLabel = 'Location is off';
const customerLocationLoadingLabel = 'Finding your location…';

// Header place name from the device, or a short status when unavailable.
class CustomerLocationTitle extends ConsumerWidget {
  const CustomerLocationTitle({super.key, this.style, this.maxLines = 1});

  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(customerLocationProvider);
    final label = placeAsync.when(
      loading: () => customerLocationLoadingLabel,
      error: (_, _) => customerLocationOffLabel,
      data: (place) {
        final text = place.label?.trim();
        if (text == null || text.isEmpty) {
          return customerLocationOffLabel;
        }
        return text;
      },
    );

    return Text(
      label,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      softWrap: true,
      style: style,
    );
  }
}