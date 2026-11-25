import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pharmacy_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Small square storefront photo for any pharmacy branch.
// Falls back to the pharmacy icon when the owner has not uploaded a photo yet.
class BranchStorefrontThumb extends ConsumerWidget {
  const BranchStorefrontThumb({
    super.key,
    required this.branchId,
    this.size = 56,
    this.isRegistered = true,
  });

  final String? branchId;
  final double size;
  final bool isRegistered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = branchId;
    String? url;
    if (id != null && id.isNotEmpty && isRegistered) {
      final path = ref.watch(branchStorefrontPathProvider(id)).value;
      if (path != null && path.isNotEmpty) {
        url = ref.watch(storefrontUrlProvider(path)).value;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _placeholder()
            : Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: isRegistered ? AppColors.primaryLight : AppColors.neutralLight,
      child: Icon(
        isRegistered ? Icons.local_pharmacy : Icons.local_pharmacy_outlined,
        color: isRegistered ? AppColors.primary : AppColors.textMuted,
        size: size * 0.45,
      ),
    );
  }
}
