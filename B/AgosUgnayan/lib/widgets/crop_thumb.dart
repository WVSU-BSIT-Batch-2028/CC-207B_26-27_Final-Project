// A small rounded square for a crop in a list row. With [crop] it shows the
// crop's sample photo from Wikipedia (over the light green placeholder);
// without it, just the placeholder with an icon.

import 'package:flutter/material.dart';

import '../utils/theme.dart';
import 'crop_image.dart';

/// A 48 px rounded square with the crop's photo or an icon.
class CropThumb extends StatelessWidget {
  const CropThumb({
    super.key,
    this.crop,
    this.size = 48,
    this.icon = Icons.eco_outlined,
    this.photoId,
  });

  /// A listing with the farmer's own photo (shown instead of the sample).
  final String? photoId;

  /// Our crop name, e.g. "Tomato". Null shows only [icon].
  final String? crop;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: crop != null
            ? CropImage(
                crop: crop!,
                size: CropImageSize.thumb,
                photoId: photoId,
              )
            : ColoredBox(
                color: AppColors.primaryLight,
                child: Icon(icon, color: AppColors.link, size: size * 0.5),
              ),
      ),
    );
  }
}
