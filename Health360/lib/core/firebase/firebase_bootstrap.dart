import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// Starts Firebase and App Check once at launch. Never crashes the app:
/// on failure the flags stay false and features use their offline fallback.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;
  static bool _appCheckReady = false;

  /// True only after Firebase started successfully.
  static bool get isReady => _ready;

  /// True when Firebase and App Check are running (the AI needs both).
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

    // App Check proves requests come from our app (required by Firebase AI Logic).
    // Live site: reCAPTCHA Enterprise. localhost: debug mode set in web/index.html.
    try {
      final siteKey = FirebaseConfig.recaptchaSiteKey.isEmpty
          ? 'debug-mode-placeholder' // local debug mode only
          : FirebaseConfig.recaptchaSiteKey;
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(siteKey),
      );
      _appCheckReady = true;
      // Fetch the first token now so the first AI message does not wait for it.
      unawaited(FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true));
      unawaited(FirebaseAppCheck.instance.getToken().then(
            (_) {},
            onError: (Object e) => debugPrint('App Check token not ready yet: $e'),
          ));
    } catch (e) {
      debugPrint('Firebase: App Check could not start, the AI assistant will use offline guidance. $e');
    }
  }
}
