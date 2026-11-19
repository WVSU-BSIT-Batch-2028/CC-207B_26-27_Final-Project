import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:websupark/config/firebase_config.dart';
import 'package:websupark/routes/app_router.dart';
import 'package:websupark/routes/app_routes.dart';
import 'package:websupark/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }

  runApp(const WebsuParkApp());
}

class WebsuParkApp extends StatelessWidget {
  const WebsuParkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WEBSUPARK',
      theme: AppTheme.light,
      routes: AppRouter.routes,
      home: const PlaceholderScreen(),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WEBSUPARK\nProject setup OK',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 280,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.driverHome),
                child: const Text('Open Driver (temporary)'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.guardConsole),
                child: const Text('Open Guard (temporary)'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.headOverview),
                child: const Text('Open Head Security (temporary)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}