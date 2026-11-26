// Browser version: keeps the signed-in ID in this tab's sessionStorage
import 'package:web/web.dart' as web;

const _key = 'founderId';

String? readFounderId() => web.window.sessionStorage.getItem(_key);

void writeFounderId(String? id) {
  if (id == null) {
    web.window.sessionStorage.removeItem(_key);
  } else {
    web.window.sessionStorage.setItem(_key, id);
  }
}
