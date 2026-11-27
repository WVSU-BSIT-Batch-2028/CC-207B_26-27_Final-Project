import 'package:firebase_core/firebase_core.dart';

/// Firebase settings, read at build time from firebase_config.json
/// (`--dart-define-from-file`). That file is git-ignored; see FIREBASE_SETUP.md.
class FirebaseConfig {
  FirebaseConfig._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// reCAPTCHA Enterprise site key for App Check on the live site.
  /// Public by design; empty when running locally (debug mode is used).
  static const String recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

  /// True when the four required values were provided.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _messagingSenderId.isNotEmpty && _projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );
}
