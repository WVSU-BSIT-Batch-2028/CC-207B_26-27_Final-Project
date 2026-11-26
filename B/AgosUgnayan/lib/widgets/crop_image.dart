// A crop's picture box, like the website's CropImage. The farmer's own photo
// comes first. Without one, it starts as the green placeholder with a leaf;
// when the crop's sample photo from Wikipedia loads, the photo covers it. Cards and big photos say "Sample photo" so nobody
// takes it for the farmer's own harvest. Offline or on error, the
// placeholder simply stays.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/crop_photo_service.dart';
import '../services/listing_photo_service.dart';
import '../utils/theme.dart';

/// How big the picture is shown.
enum CropImageSize {
  /// Small square in a list row (no label, it would not fit).
  thumb,

  /// Marketplace card.
  card,

  /// The big photo at the top of a page, with the photo credit under it.
  hero,
}

/// The picture for [crop]. The box's size comes from its parent.
/// With [photoId] (a listing with the farmer's own photo) that photo is
/// shown; if it can't load, the crop's sample photo is shown instead.
class CropImage extends StatelessWidget {
  const CropImage({
    super.key,
    required this.crop,
    required this.size,
    this.photoId,
  });

  final String crop;
  final CropImageSize size;
  final String? photoId;

  @override
  Widget build(BuildContext context) {
    final id = photoId;
    if (id == null) return _SampleImage(crop: crop, size: size);
    return FutureBuilder<Uint8List?>(
      future: ListingPhotoService.instance.photoFor(id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) return FarmerPhoto(bytes: bytes);
        if (snapshot.connectionState == ConnectionState.done) {
          return _SampleImage(crop: crop, size: size); // no photo after all
        }
        return _Placeholder(size: size); // still loading
      },
    );
  }
}

/// The farmer's own photo, filling its box. Not labeled "Sample": it is
/// the real harvest.
class FarmerPhoto extends StatelessWidget {
  const FarmerPhoto({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true, // no flicker when the card rebuilds
      excludeFromSemantics: true, // the crop name is written next to it
    );
  }
}

/// The light green box with a leaf, shown while nothing else is there.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final CropImageSize size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      child: Icon(
        Icons.eco_outlined,
        color: AppColors.link,
        size: size == CropImageSize.thumb ? 24 : 40,
      ),
    );
  }
}

/// The crop's sample photo from Wikipedia over the placeholder.
class _SampleImage extends StatelessWidget {
  const _SampleImage({required this.crop, required this.size});

  final String crop;
  final CropImageSize size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CropPhoto?>(
      future: CropPhotoService.instance.photoFor(crop),
      builder: (context, snapshot) {
        final photo = snapshot.data;
        final source = photo == null
            ? null
            : size == CropImageSize.hero
            ? photo.largeImage
            : photo.image;
        return Stack(
          fit: StackFit.expand,
          children: [
            // The placeholder is always underneath.
            _Placeholder(size: size),
            if (source != null)
              Image.network(
                source,
                fit: BoxFit.cover,
                // Decorative: the crop name is always written next to it.
                excludeFromSemantics: true,
                // On error show nothing, so the placeholder stays visible.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                frameBuilder: (context, child, frame, _) => AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                ),
              ),
            if (source != null && size != CropImageSize.thumb)
              const Positioned(left: 8, bottom: 8, child: _SampleTag()),
          ],
        );
      },
    );
  }
}

/// The dark "Sample photo" label in the corner of a photo.
class _SampleTag extends StatelessWidget {
  const _SampleTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Sample photo',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A big rounded crop photo with the photo credit under it, for the top of
/// Listing details and Price details.
class CropHero extends StatelessWidget {
  const CropHero({super.key, required this.crop, this.note, this.photoId});

  final String crop;

  /// Optional line above the credit, e.g. that this is not the farmer's photo.
  final String? note;

  /// A listing with the farmer's own photo: show that instead.
  final String? photoId;

  @override
  Widget build(BuildContext context) {
    final id = photoId;
    if (id == null) return _sampleHero();
    return FutureBuilder<Uint8List?>(
      future: ListingPhotoService.instance.photoFor(id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return snapshot.connectionState == ConnectionState.done
              ? _sampleHero()
              : const AspectRatio(aspectRatio: 16 / 9);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FarmerPhoto(bytes: bytes),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Photo from the farmer', style: AppTextStyles.meta),
            ),
          ],
        );
      },
    );
  }

  /// The Wikipedia sample photo with its credit.
  Widget _sampleHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CropImage(crop: crop, size: CropImageSize.hero),
          ),
        ),
        FutureBuilder<CropPhoto?>(
          future: CropPhotoService.instance.photoFor(crop),
          builder: (context, snapshot) {
            final photo = snapshot.data;
            if (photo == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [?note, photo.creditText].join(' '),
                style: AppTextStyles.meta,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// "About tomato": the first sentences of the crop's Wikipedia article.
/// Hidden until it loads (and when there is none).
class CropAbout extends StatelessWidget {
  const CropAbout({super.key, required this.crop});

  final String crop;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CropPhoto?>(
      future: CropPhotoService.instance.photoFor(crop),
      builder: (context, snapshot) {
        final extract = snapshot.data?.extract;
        if (extract == null) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About ${crop.toLowerCase()}',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 6),
                Text(extract, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                const Text('Source: Wikipedia', style: AppTextStyles.meta),
              ],
            ),
          ),
        );
      },
    );
  }
}
