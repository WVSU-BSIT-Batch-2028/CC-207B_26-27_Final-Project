import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bahinko/firebase_options.dart';
import 'package:bahinko/screens/main_pages_preview.dart';
// Private App Check debug token. NOT in git.
import 'package:bahinko/secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _startAppCheck();
  runApp(const BahinKoPreviewApp());
}

/// App Check proves AI requests come from the real app. Phones only; web and
/// desktop skip it. Never blocks startup: without it the scanner falls back
/// to basic detection.
Future<void> _startAppCheck() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(
        debugToken: appCheckDebugToken,
      ),
    );
  } catch (_) {}
}
