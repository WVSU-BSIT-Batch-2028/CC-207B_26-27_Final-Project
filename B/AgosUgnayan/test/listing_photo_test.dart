// Tests for shrinking farmers' photos and for listing titles.

import 'dart:typed_data';

import 'package:agosugnayan/models/listing.dart';
import 'package:agosugnayan/utils/app_exception.dart';
import 'package:agosugnayan/utils/photo_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A noisy test picture (noise is hard to compress, like a real photo).
Uint8List _photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  var seed = 7;
  for (final pixel in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixel
      ..r = seed % 256
      ..g = (seed >> 8) % 256
      ..b = (seed >> 16) % 256;
  }
  return img.encodePng(image);
}

Listing _listing({String title = ''}) => Listing(
  id: 'a',
  farmerId: 'f',
  farmerName: 'Juan',
  crop: 'Pechay',
  quantity: 20,
  unit: 'kg',
  price: 54.4,
  town: 'Leon',
  harvestDate: null,
  description: '',
  aiAssisted: false,
  createdAt: DateTime(2026, 11, 23),
  title: title,
);

void main() {
  test('a big photo becomes a JPEG of at most 800 px and 300 KB', () {
    final jpeg = compressPhoto(_photo(1600, 1000));
    final result = img.decodeJpg(jpeg)!;
    expect(result.width, 800);
    expect(result.height, 500);
    expect(jpeg.length, lessThanOrEqualTo(kPhotoMaxBytes));
  });

  test('a tall photo keeps its shape', () {
    final result = img.decodeJpg(compressPhoto(_photo(600, 1200)))!;
    expect(result.height, 800);
    expect(result.width, 400);
  });

  test('a file that is not a picture is refused with a clear message', () {
    expect(
      () => compressPhoto(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<AppException>()),
    );
  });

  test('the headline is the title, or the crop when there is none', () {
    expect(_listing().headline, 'Pechay');
    final titled = _listing(title: "Juan's Food Stall");
    expect(titled.headline, "Juan's Food Stall");
    expect(titled.crop, 'Pechay'); // the real crop stays separate
  });

  test('title and photo flag are saved and read back', () {
    final map = _listing(title: 'Stall 5').toMap()..['hasPhoto'] = true;
    final back = Listing.fromMap('a', {...map, 'createdAt': DateTime(2026)});
    expect(back.title, 'Stall 5');
    expect(back.photoId, 'a');
    final old = Listing.fromMap('b', {'crop': 'Tomato'});
    expect(old.title, '');
    expect(old.photoId, isNull);
  });
}
