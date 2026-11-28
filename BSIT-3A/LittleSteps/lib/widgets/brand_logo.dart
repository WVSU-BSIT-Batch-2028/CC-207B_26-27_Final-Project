import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_tokens.dart';

/// Displays the LittleSteps brandmark emblem.
///
/// Loads the vector asset from [assetPath] using [SvgPicture.asset].
class GrowthSymbol extends StatelessWidget {
  /// Creates a [GrowthSymbol].
  const GrowthSymbol({
    super.key,
    this.size = 28.0,
    this.assetPath = 'assets/brand/brandmark.svg',
  });

  /// The width and height of the symbol.
  final double size;

  /// The asset path to the brandmark SVG file.
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(assetPath, width: size, height: size);
  }
}

/// Header lockup that pairs the growth symbol emblem with the LittleSteps wordmark.
///
/// Supports an optional tagline and tap gesture callback for navigation.
class BrandLogo extends StatelessWidget {
  /// Creates a [BrandLogo].
  const BrandLogo({
    super.key,
    this.symbolSize = 26.0,
    this.showTagline = false,
    this.onTap,
  });

  /// Size of the growth symbol.
  final double symbolSize;

  /// Whether to render the tagline beneath the wordmark.
  final bool showTagline;

  /// Optional tap handler (for example, to return to the Today tab).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final logoWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (symbolSize > 0) ...[
          GrowthSymbol(size: symbolSize),
          const SizedBox(width: AppSpacing.space8),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LittleSteps',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest,
                  letterSpacing: -0.3,
                ),
              ),
              if (showTagline)
                Text(
                  'Small steps. Brighter tomorrows.',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space4,
          ),
          child: logoWidget,
        ),
      );
    }

    return logoWidget;
  }
}

/// Displays the decorative parent and child brand illustration.
///
/// Used in welcome screens, authentication cards, and onboarding states.
class ParentChildIllustration extends StatelessWidget {
  /// Creates a [ParentChildIllustration].
  const ParentChildIllustration({
    super.key,
    this.width,
    this.height = 130.0,
    this.assetPath = 'assets/brand/illustration_parent_child.svg',
  });

  /// The rendered width of the illustration.
  final double? width;

  /// The rendered height of the illustration.
  final double height;

  /// The asset path to the illustration SVG.
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
