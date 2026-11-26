// Shrinks a farmer's crop photo before we save it. We have no Firebase
// Storage on the free plan, so photos are saved inside Firestore, which
// allows at most 1 MB per document. Small photos also load faster on
// slow mobile data.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'app_exception.dart';

/// The longest side of a saved photo, in pixels.
const int kPhotoMaxSide = 800;

/// The size we aim for (150 KB) and the most we accept (300 KB).
const int kPhotoTargetBytes = 150 * 1024;
const int kPhotoMaxBytes = 300 * 1024;

/// Returns [original] as a JPEG of at most 800 px on the longest side.
/// Tries quality 70 first and lowers it until the photo is small enough.
/// Throws an [AppException] when the file is not a picture, or when it
/// can't be made smaller than [kPhotoMaxBytes].
Uint8List compressPhoto(Uint8List original) {
  final decoded = img.decodeImage(original);
  if (decoded == null) {
    throw const AppException(
      'That file is not a photo. Choose a JPG or PNG picture.',
    );
  }
  // Phones save "which way is up" separately; apply it before resizing.
  final upright = img.bakeOrientation(decoded);
  final isWide = upright.width >= upright.height;
  final tooBig =
      upright.width > kPhotoMaxSide || upright.height > kPhotoMaxSide;
  final resized = !tooBig
      ? upright
      : img.copyResize(
          upright,
          width: isWide ? kPhotoMaxSide : null,
          height: isWide ? null : kPhotoMaxSide,
          interpolation: img.Interpolation.average,
        );

  Uint8List? smallest;
  for (final quality in const [70, 60, 50, 40]) {
    final jpeg = img.encodeJpg(resized, quality: quality);
    if (jpeg.length <= kPhotoTargetBytes) return jpeg;
    smallest = jpeg;
  }
  // Not under the target even at quality 40: still fine up to the maximum.
  if (smallest != null && smallest.length <= kPhotoMaxBytes) return smallest;
  throw const AppException(
    'This photo is too large to save. Try another photo.',
  );
}
