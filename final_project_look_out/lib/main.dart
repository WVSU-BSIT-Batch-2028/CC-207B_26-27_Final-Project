import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
//firebase
import 'package:firebase_core/firebase_core.dart';

// Theme configuration
import './app/themes/app_theme.dart';

// Pages
import './features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
  final appId = dotenv.env['APP_ID'] ?? '';
  final messagingId = dotenv.env['MESSAGING_SENDER_ID'] ?? '';
  final projectId = dotenv.env['PROJECT_ID'] ?? '';

  if (firebaseApiKey.isEmpty) {
    throw StateError(
      'FIREBASE_API_KEY is missing. Build or run with '
      '--dart-define-from-file=.env.json.',
    );
  }
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: appId,
      messagingSenderId: messagingId,
      projectId: projectId,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LookOut!',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
