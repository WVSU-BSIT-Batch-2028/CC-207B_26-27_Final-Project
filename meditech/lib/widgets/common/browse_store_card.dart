import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/public_media_urls.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'branch_storefront_thumb.dart';

// Main Flow home store row: thumbnail, rating, open/registered badges
class BrowseStoreCard extends StatelessWidget {
  const BrowseStoreCard({
    super.key,
    required this.name,
    required this.addressLine,
    this.branchId,
    this.storefrontPath,
    this.rating = 4.2,
    this.reviewCount = 40,
    this.isOpen = true,
    this.isRegistered = true,
    this.onTap,
  });

  final String name;
  final String addressLine;
  final String? branchId;
  final String? storefrontPath;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final bool isRegistered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (branchId != null && branchId!.isNotEmpty)
                BranchStorefrontThumb(
                  branchId: branchId,
                  size: 64,
                  isRegistered: isRegistered,
                )
              else
                _StorefrontThumb(
                  storefrontPath: storefrontPath,
                  isRegistered: isRegistered,
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (isRegistered) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Color(0xFFF5A623),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            ' ($reviewCount)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (isRegistered) ...[
                          _Pill(
                            label: isOpen ? 'Open' : 'Closed',
                            background: isOpen
                                ? AppColors.primaryLight
                                : AppColors.dangerLight,
                            foreground: isOpen
                                ? AppColors.primary
                                : AppColors.danger,
                          ),
                          const _Pill(
                            label: 'Registered on MediTech',
                            background: AppColors.primaryLight,
                            foreground: AppColors.primary,
                          ),
                        ] else
                          const _Pill(
                            label: 'Not on MediTech',
                            background: AppColors.neutralLight,
                            foreground: AppColors.textMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _StorefrontThumb extends StatefulWidget {
  const _StorefrontThumb({
    required this.storefrontPath,
    required this.isRegistered,
  });

  final String? storefrontPath;
  final bool isRegistered;

  @override
  State<_StorefrontThumb> createState() => _StorefrontThumbState();
}

class _StorefrontThumbState extends State<_StorefrontThumb> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _StorefrontThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storefrontPath != widget.storefrontPath) _resolve();
  }

  Future<void> _resolve() async {
    if (widget.storefrontPath == null || widget.storefrontPath!.isEmpty) {
      if (mounted) setState(() => _url = null);
      return;
    }
    final url = await pharmacyStorefrontSignedUrl(
      Supabase.instance.client,
      widget.storefrontPath,
    );
    if (mounted) setState(() => _url = url);
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      color: widget.isRegistered ? AppColors.primaryLight : AppColors.neutralLight,
      child: Icon(
        widget.isRegistered ? Icons.local_pharmacy : Icons.local_pharmacy_outlined,
        color: widget.isRegistered ? AppColors.primary : AppColors.textMuted,
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 64,
        height: 64,
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
}
