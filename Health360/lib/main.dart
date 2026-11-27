import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/theme_controller.dart';

/// App entry point: loads settings, starts Firebase, then runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply the saved light/dark choice before the first frame.
  await ThemeController.instance.load();
  // Start Firebase (skipped if firebase_config.json is missing).
  await FirebaseBootstrap.init();
  runApp(const Health360App());
}
