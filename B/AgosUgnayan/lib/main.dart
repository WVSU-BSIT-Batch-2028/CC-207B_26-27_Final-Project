// App entry point: catches every error so it gets logged, connects to
// Firebase, then starts the app with our theme on the start screen.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/start_screen.dart';
import 'services/assistant_controller.dart';
import 'utils/app_logger.dart';
import 'utils/strings.dart';
import 'utils/theme.dart';
import 'widgets/assistant_layer.dart';

void main() {
  // runZonedGuarded catches errors from async code that nothing else caught.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Errors inside Flutter widgets (build, layout, paint) come here.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.error('Flutter error', details.exception, details.stack);
    };
    final firebaseReady = await connectFirebase();
    runApp(AgosUgnayanApp(firebaseReady: firebaseReady));
  }, (error, stack) => AppLogger.error('Uncaught error', error, stack));
}

/// True when the app was started with --dart-define=USE_EMULATOR=true.
/// Then it uses the Firebase Emulator on this computer instead of our real
/// Firebase project, so we can test without internet or a project.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');

/// Connects to Firebase using lib/firebase_options.dart.
/// Returns false (instead of crashing) when the file still has placeholder
/// values or the connection fails, so the app can explain what to do.
Future<bool> connectFirebase() async {
  if (useEmulator) return connectEmulator();
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.apiKey == 'REPLACE_ME') {
    AppLogger.info('Firebase skipped: run `flutterfire configure` first.');
    return false;
  }
  try {
    await Firebase.initializeApp(options: options);
    return true;
  } on FirebaseException catch (e, stack) {
    AppLogger.error('Firebase.initializeApp failed', e, stack);
    return false;
  }
}

/// Connects to the local Firebase Emulator (see README, "Test without a
/// Firebase project"). "demo-" project ids never touch real Firebase.
Future<bool> connectEmulator() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:1:web:1',
        messagingSenderId: '1',
        projectId: 'demo-agosugnayan',
      ),
    );
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    AppLogger.info('Using the Firebase Emulator on this computer.');
    return true;
  } catch (e, stack) {
    AppLogger.error('Could not connect to the emulator', e, stack);
    return false;
  }
}

/// The root widget: applies the theme and opens the start screen.
class AgosUgnayanApp extends StatelessWidget {
  const AgosUgnayanApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // The buyer AI assistant sits above every page (it shows only while
      // a buyer is logged in). The key lets its answer cards open pages;
      // the observer hides its button while a sheet or dialog is open.
      navigatorKey: AssistantController.navigatorKey,
      navigatorObservers: [AssistantRouteObserver()],
      builder: (context, child) => AssistantLayer(child: child!),
      // The app fills the whole window. Each screen limits its own content
      // width on big screens (see widgets/responsive_body.dart).
      home: StartScreen(firebaseReady: firebaseReady),
    );
  }
}
