import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply the saved light/dark choice before the first frame.
  await ThemeController.instance.load();
  runApp(const Health360App());
}
