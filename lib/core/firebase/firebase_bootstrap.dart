import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// Starts Firebase once, when the app launches.
///
/// It never crashes the app: if the config file is missing (a teammate has not
/// set it up yet) or startup fails, the flags stay false and features that need
/// Firebase use their offline fallback instead.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;
  static bool _appCheckReady = false;

  /// True only after Firebase started successfully.
  static bool get isReady => _ready;

  /// True when Firebase AND App Check are running. The AI assistant needs both.
  static bool get isAiReady => _ready && _appCheckReady;

  static Future<void> init() async {
    if (!FirebaseConfig.isConfigured) {
      debugPrint('Firebase: no config found, running without it (see FIREBASE_SETUP.md).');
      return;
    }

    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      _ready = true;
    } catch (e) {
      debugPrint('Firebase: startup failed, running without it. $e');
      return;
    }

    // App Check proves that requests come from our app. Firebase AI Logic REQUIRES it.
    // On the web, debug mode is switched on in web/index.html (local development only):
    // the browser console then prints a debug token that must be registered in the
    // Firebase console (see FIREBASE_SETUP.md, "App Check").
    // If your editor says `providerWeb` does not exist, your package is older: use `webProvider`.
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider('debug-mode-placeholder'),
      );
      _appCheckReady = true;
    } catch (e) {
      debugPrint('Firebase: App Check could not start, the AI assistant will use offline guidance. $e');
    }
  }
}
