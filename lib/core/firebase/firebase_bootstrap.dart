import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// Starts Firebase once, when the app launches.
///
/// It never crashes the app: if the config file is missing (a teammate has not
/// set it up yet) or startup fails, [isReady] stays false and features that need
/// Firebase use their offline fallback instead.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;

  /// True only after Firebase started successfully.
  static bool get isReady => _ready;

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
    }
  }
}
