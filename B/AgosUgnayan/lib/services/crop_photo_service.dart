// Sample crop photos from Wikipedia, like the website (app/src/lib/
// cropPhotos.ts). Free, no account or key. They show where a crop has no
// photo of its own and are always labeled "Sample photo", so nobody takes
// them for a farmer's real harvest. Each photo keeps its author and license.
//
// With 71 crops we load photos LAZILY: a crop's photo is asked for only when
// a card on screen needs it, at most 2 requests at a time (Wikipedia blocks
// apps that ask too fast). Every photo is saved on the phone for a week and
// the saved copy is used offline. If Wikipedia can't be reached, crops keep
// the green leaf placeholder.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import '../utils/crop_catalog.dart';

/// Our crop name -> its English Wikipedia article (from the crop catalog).
final Map<String, String> kCropArticles = {
  for (final crop in kCropCatalog) crop.name: crop.wikipedia,
};

/// One crop's sample photo and where it comes from.
class CropPhoto {
  const CropPhoto({
    required this.image,
    required this.largeImage,
    required this.description,
    required this.extract,
    required this.author,
    required this.license,
  });

  /// About 330 px wide: enough for lists and cards.
  final String image;

  /// A sharper copy for the big photo at the top of a page.
  final String largeImage;

  /// Short description, e.g. "Edible berry".
  final String? description;

  /// The first sentences of the Wikipedia article.
  final String? extract;

  /// Who took the photo and its license, e.g. "Jane Doe" and "CC BY-SA 4.0".
  final String? author;
  final String? license;

  /// e.g. "Sample photo: Jane Doe, CC BY-SA 4.0, via Wikipedia".
  String get creditText {
    final parts = [?author, ?license];
    return parts.isEmpty
        ? 'Sample photo from Wikipedia'
        : 'Sample photo: ${parts.join(', ')}, via Wikipedia';
  }

  factory CropPhoto.fromMap(Map<String, dynamic> map) => CropPhoto(
    image: map['image'] as String,
    largeImage: map['largeImage'] as String? ?? map['image'] as String,
    description: map['description'] as String?,
    extract: map['extract'] as String?,
    author: map['author'] as String?,
    license: map['license'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'image': image,
    'largeImage': largeImage,
    'description': description,
    'extract': extract,
    'author': author,
    'license': license,
  };
}

/// Loads and remembers the sample photos. Use [CropPhotoService.instance] so
/// every screen shares one copy.
class CropPhotoService {
  CropPhotoService({http.Client? client}) : _client = client ?? http.Client();

  /// The one shared copy the app uses.
  static final CropPhotoService instance = CropPhotoService();

  final http.Client _client;

  static const _api = 'https://en.wikipedia.org';
  static const _storeKey = 'crop_photos_v2'; // one entry per article
  static const _fresh = Duration(days: 7);
  static const _retryAfter = Duration(minutes: 1);
  static const _timeout = Duration(seconds: 10);
  static const _maxAtOnce = 2; // Wikipedia answers "429 too many" if faster

  /// Saved photos by article title, with when each was saved.
  final Map<String, CropPhoto?> _photos = {};
  final Map<String, DateTime> _savedAt = {};
  final Map<String, DateTime> _failedAt = {};
  final Map<String, Future<CropPhoto?>> _pending = {};
  bool _readSavedDone = false;

  // A small waiting line so only [_maxAtOnce] downloads run together.
  int _running = 0;
  final Queue<Completer<void>> _waiting = Queue();

  /// The sample photo for [crop] (our crop name), or null if there is none
  /// or it can't be loaded now. Never throws.
  Future<CropPhoto?> photoFor(String crop) async {
    final article = kCropArticles[crop];
    if (article == null) return null;
    if (!_readSavedDone) await _readSaved();

    final now = DateTime.now();
    final saved = _savedAt[article];
    if (saved != null && now.difference(saved) < _fresh) {
      return _photos[article];
    }
    final failed = _failedAt[article];
    if (failed != null && now.difference(failed) < _retryAfter) {
      return _photos[article]; // an older saved copy, or null
    }
    // If several cards show the same crop, they share one download.
    return _pending[article] ??= _load(article)
        .whenComplete(() => _pending.remove(article));
  }

  Future<CropPhoto?> _load(String article) async {
    await _takeTurn();
    try {
      final photo = await fetchFromWikipedia(article);
      _photos[article] = photo;
      _savedAt[article] = DateTime.now();
      await _writeSaved();
      return photo;
    } catch (e) {
      AppLogger.error('Loading the photo for $article failed', e);
      _failedAt[article] = DateTime.now();
      return _photos[article];
    } finally {
      _endTurn();
    }
  }

  Future<void> _takeTurn() async {
    if (_running < _maxAtOnce) {
      _running++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future; // _endTurn hands its place to us
  }

  void _endTurn() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete(); // the next one takes this place
    } else {
      _running--;
    }
  }

  /// Loads one article's photo, description and photo credit from
  /// Wikipedia now (no saved copy). Returns null when it has no photo.
  Future<CropPhoto?> fetchFromWikipedia(String article) async {
    final summary = await _getJson(
      '$_api/api/rest_v1/page/summary/'
      '${Uri.encodeComponent(article.replaceAll(' ', '_'))}?redirect=true',
    );
    final thumb = (summary['thumbnail'] as Map?)?['source'] as String?;
    if (thumb == null) return null;
    final original = (summary['originalimage'] as Map?)?['source'] as String?;
    final originalWidth = (summary['originalimage'] as Map?)?['width'] as int?;
    final file = fileNameOf(original ?? thumb);
    final credit = file == null ? null : await _loadCredit(file);
    final description = (summary['description'] as String?)?.trim();
    return CropPhoto(
      image: thumb,
      largeImage: widerThumb(thumb, originalWidth, 960),
      description: description == null || description.isEmpty
          ? null
          : description,
      extract: shortExtract(summary['extract'] as String?),
      author: credit?.author,
      license: credit?.license,
    );
  }

  /// Author and license of one photo file. If it fails the photo still
  /// shows, just without names.
  Future<_Credit?> _loadCredit(String file) async {
    try {
      final uri = Uri.parse('$_api/w/api.php').replace(
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'formatversion': '2',
          'origin': '*',
          'prop': 'imageinfo',
          'iiprop': 'extmetadata',
          'iiextmetadatafilter': 'Artist|LicenseShortName',
          'titles': 'File:$file',
        },
      );
      final answer = await _getJson(uri.toString());
      final pages = (answer['query'] as Map?)?['pages'] as List? ?? [];
      if (pages.isEmpty) return null;
      final info = (pages.first as Map)['imageinfo'] as List?;
      if (info == null || info.isEmpty) return null;
      final meta = (info.first as Map)['extmetadata'] as Map? ?? {};
      return _Credit(
        plainText((meta['Artist'] as Map?)?['value'] as String?),
        plainText(
          (meta['LicenseShortName'] as Map?)?['value'] as String?,
          max: 40,
        ),
      );
    } catch (e) {
      AppLogger.error('Loading photo credit failed', e);
      return null;
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Wikipedia answered ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> _readSaved() async {
    _readSavedDone = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in saved.entries) {
        final item = entry.value as Map<String, dynamic>;
        _savedAt[entry.key] = DateTime.parse(item['savedAt'] as String);
        final photo = item['photo'] as Map<String, dynamic>?;
        _photos[entry.key] = photo == null ? null : CropPhoto.fromMap(photo);
      }
    } catch (e) {
      AppLogger.error('Reading saved crop photos failed', e); // not fatal
    }
  }

  Future<void> _writeSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          for (final entry in _savedAt.entries)
            entry.key: {
              'savedAt': entry.value.toIso8601String(),
              'photo': _photos[entry.key]?.toMap(),
            },
        }),
      );
    } catch (e) {
      AppLogger.error('Saving crop photos failed', e); // loads again next time
    }
  }
}

/// A photo's author and license.
class _Credit {
  const _Credit(this.author, this.license);

  final String? author;
  final String? license;
}

/// Wikimedia thumbnail links contain `/330px-FILE`; this asks for a wider
/// copy (e.g. 960 px) when the original photo is that wide.
String widerThumb(String thumb, int? originalWidth, int width) {
  if (originalWidth == null || originalWidth <= width) return thumb;
  return thumb.replaceFirstMapped(RegExp(r'/(\d+)px-([^/?#]+)'), (match) {
    final current = int.parse(match[1]!);
    return current < width ? '/${width}px-${match[2]}' : match[0]!;
  });
}

/// "Tomato je.jpg" from a Wikimedia image link (thumbnail or original).
String? fileNameOf(String url) {
  final match = RegExp(
    r'/wikipedia/[^/]+/(?:thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?#]+)',
  ).firstMatch(url);
  if (match == null) return null;
  try {
    return Uri.decodeComponent(match[1]!).replaceAll('_', ' ');
  } catch (_) {
    return null;
  }
}

/// Author fields come as HTML (often a link); keep only the short plain text.
String? plainText(String? html, {int max = 80}) {
  if (html == null) return null;
  final text = html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;
  return text.length > max
      ? '${text.substring(0, max - 1).trimRight()}…'
      : text;
}

/// At most [max] characters, cut at the end of a sentence when there is one.
String? shortExtract(String? text, {int max = 320}) {
  final s = text?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s == null || s.isEmpty) return null;
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final end = cut.lastIndexOf('. ');
  if (end > 80) return cut.substring(0, end + 1);
  return '${cut.substring(0, cut.lastIndexOf(' ')).trimRight()}…';
}
