// PLACEHOLDER Firebase settings. The real lib/firebase_options.dart is made by
// `flutterfire configure` on each laptop and is NOT committed (see .gitignore
// and the README). CI copies this file to lib/firebase_options.dart so the
// code can be analyzed and tested without our Firebase project's settings.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Same shape as the file FlutterFire generates, with fake values.
class DefaultFirebaseOptions {
  /// Marks these options as fake so main.dart skips connecting to Firebase.
  static const String placeholder = 'REPLACE_ME';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('AgosUgnayan only targets web and Android.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: placeholder,
    appId: placeholder,
    messagingSenderId: placeholder,
    projectId: placeholder,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: placeholder,
    appId: placeholder,
    messagingSenderId: placeholder,
    projectId: placeholder,
  );
}
