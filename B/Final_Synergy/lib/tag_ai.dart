import 'tag_classify_stub.dart'
    if (dart.library.js_interop) 'tag_classify_web.dart';
import 'tag_split.dart';

export 'tag_split.dart';

Future<List<String>> suggestTags(String boxText) async {
  final tags = <String>{};
  for (final piece in splitPieces(boxText)) {
    final tag = await classifyTag(piece);
    if (tag != 'none') tags.add(tag);
  }
  return tags.toList();
}
