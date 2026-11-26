// Split at . , ; ! ? line breaks and the word "and" (any case)
List<String> splitPieces(String text) => text
    .split(RegExp(r'[.,;!?\n]|\band\b', caseSensitive: false))
    .map((piece) => piece.trim())
    .where((piece) => piece.length >= 4)
    .toList();
