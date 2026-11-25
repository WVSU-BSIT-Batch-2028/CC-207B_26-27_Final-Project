import 'dart:js_interop';
import 'dart:typed_data';

@JS('wayfinderSchedule.put')
external JSPromise<JSAny?> _put(JSString id, JSUint8Array bytes);
@JS('wayfinderSchedule.get')
external JSPromise<JSUint8Array> _get(JSString id);
@JS('wayfinderSchedule.remove')
external JSPromise<JSAny?> _remove(JSString id);
@JS('wayfinderSchedule.recognize')
external JSPromise<JSString> _recognize(JSUint8Array bytes);

Future<void> putBrowserFile(String id, Uint8List bytes) async {
  await _put(id.toJS, bytes.toJS).toDart;
}

Future<Uint8List> getBrowserFile(String id) async =>
    (await _get(id.toJS).toDart).toDart;
Future<void> removeBrowserFile(String id) async {
  await _remove(id.toJS).toDart;
}

Future<String> recognizeBrowserImage(Uint8List bytes) async =>
    (await _recognize(bytes.toJS).toDart).toDart;
