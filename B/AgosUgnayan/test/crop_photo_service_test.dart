// Unit tests for the Wikipedia sample crop photos: the small text and link
// helpers, and the whole download with a fake Wikipedia (MockClient).

import 'dart:convert';

import 'package:agosugnayan/services/crop_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A real-looking Wikipedia thumbnail link, with the tracking part at the end.
const thumb =
    'https://thumb.wikimedia.org/wikipedia/commons/thumb/8/89/Tomato_je.jpg/'
    '330px-Tomato_je.jpg?utm_source=en.wikipedia.org';

void main() {
  test('every crop has a Wikipedia article, like the website', () {
    expect(kCropArticles.length, 71);
    expect(kCropArticles['Pechay'], 'Bok choy');
  });

  test('widerThumb asks for a wider copy only when the original is wider', () {
    expect(widerThumb(thumb, 1800, 960), contains('/960px-Tomato_je.jpg'));
    expect(widerThumb(thumb, 300, 960), thumb);
    expect(widerThumb(thumb, null, 960), thumb);
  });

  test('fileNameOf reads the file name from a photo link', () {
    expect(fileNameOf(thumb), 'Tomato je.jpg');
    expect(fileNameOf('https://example.com/x.jpg'), isNull);
  });

  test('plainText removes HTML and shortens long names', () {
    expect(plainText('<a href="x">Jane Doe</a>'), 'Jane Doe');
    expect(plainText('   '), isNull);
    expect(plainText('a' * 100, max: 10)!.length, 10);
  });

  test('shortExtract cuts at the end of a sentence', () {
    final text = '${'Tomatoes are red. ' * 30}End';
    final short = shortExtract(text, max: 100)!;
    expect(short.length, lessThanOrEqualTo(100));
    expect(short.endsWith('.'), isTrue);
  });

  test('creditText names the author and license', () {
    const photo = CropPhoto(
      image: thumb,
      largeImage: thumb,
      description: null,
      extract: null,
      author: 'Jane Doe',
      license: 'CC BY-SA 4.0',
    );
    expect(
      photo.creditText,
      'Sample photo: Jane Doe, CC BY-SA 4.0, via Wikipedia',
    );
  });

  test('fetchFromWikipedia builds photos with credits', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/page/summary/')) {
        // Only Tomato has a photo in our fake Wikipedia.
        if (!request.url.path.endsWith('/Tomato')) {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'description': 'Edible berry',
            'extract': 'The tomato is a plant.',
            'thumbnail': {'source': thumb, 'width': 330},
            'originalimage': {'source': thumb, 'width': 1800},
          }),
          200,
        );
      }
      // The photo credits call.
      return http.Response(
        jsonEncode({
          'query': {
            'pages': [
              {
                'title': 'File:Tomato je.jpg',
                'imageinfo': [
                  {
                    'extmetadata': {
                      'Artist': {'value': '<a href="u">Jane Doe</a>'},
                      'LicenseShortName': {'value': 'CC BY-SA 4.0'},
                    },
                  },
                ],
              },
            ],
          },
        }),
        200,
      );
    });

    final service = CropPhotoService(client: client);
    final tomato = (await service.fetchFromWikipedia('Tomato'))!;
    expect(tomato.description, 'Edible berry');
    expect(tomato.author, 'Jane Doe');
    expect(tomato.largeImage, contains('/960px-'));
  });

  test('an article without a photo gives null', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    final photo = await CropPhotoService(client: client)
        .fetchFromWikipedia('Calabaza');
    expect(photo, isNull);
  });

  test('fetchFromWikipedia fails when Wikipedia is down', () async {
    final client = MockClient((_) async => http.Response('down', 503));
    expect(
      () => CropPhotoService(client: client).fetchFromWikipedia('Tomato'),
      throwsException,
    );
  });
}
