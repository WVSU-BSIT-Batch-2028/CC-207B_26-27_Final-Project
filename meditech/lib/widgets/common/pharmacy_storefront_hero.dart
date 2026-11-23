import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/public_media_urls.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Branch storefront banner on customer pharmacy details (signed URL).
class PharmacyStorefrontHero extends StatefulWidget {
  const PharmacyStorefrontHero({super.key, this.storefrontPath, this.height = 140});

  final String? storefrontPath;
  final double height;

  @override
  State<PharmacyStorefrontHero> createState() => _PharmacyStorefrontHeroState();
}

class _PharmacyStorefrontHeroState extends State<PharmacyStorefrontHero> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant PharmacyStorefrontHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storefrontPath != widget.storefrontPath) _resolve();
  }

  Future<void> _resolve() async {
    if (widget.storefrontPath == null || widget.storefrontPath!.isEmpty) {
      if (mounted) setState(() => _imageUrl = null);
      return;
    }
    final url = await pharmacyStorefrontSignedUrl(
      Supabase.instance.client,
      widget.storefrontPath,
    );
    if (mounted) setState(() => _imageUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: url == null
            ? ColoredBox(
                color: AppColors.primaryLight,
                child: const Icon(Icons.storefront, size: 48, color: AppColors.primary),
              )
            : Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.primaryLight,
                  child: const Icon(Icons.storefront, size: 48, color: AppColors.primary),
                ),
              ),
      ),
    );
  }
}