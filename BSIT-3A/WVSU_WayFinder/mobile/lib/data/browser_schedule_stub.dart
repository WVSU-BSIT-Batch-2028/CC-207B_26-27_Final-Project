import 'dart:typed_data';

Never _unavailable() => throw UnsupportedError('Browser schedule reader');
Future<void> putBrowserFile(String id, Uint8List bytes) async => _unavailable();
Future<Uint8List> getBrowserFile(String id) async => _unavailable();
Future<void> removeBrowserFile(String id) async => _unavailable();
Future<String> recognizeBrowserImage(Uint8List bytes) async => _unavailable();
