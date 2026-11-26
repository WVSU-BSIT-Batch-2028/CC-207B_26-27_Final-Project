import 'dart:js_interop';

@JS('classifyTag')
external JSPromise<JSString> _classifyTag(JSString text);

// Runs the in-browser model from web/tag_classifier.js
Future<String> classifyTag(String text) async =>
    (await _classifyTag(text.toJS).toDart).toDart;
