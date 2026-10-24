import 'package:flutter/material.dart';
import 'package:websupark/theme/app_theme.dart';
import 'package:websupark/routes/app_routes.dart';
import 'package:websupark/routes/app_router.dart';
// Entry point: Flutter starts running the app from here.
void main() {
  runApp(const WebsuParkApp());
}

// The root widget of the whole app. Later, the theme and routes
// will move into their own files (lib/theme, lib/routes).
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

// Temporary start page. It will be replaced by login / role selection.
// The button below lets us open the driver interface while we build it.
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
              width: 240,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.driverHome),
                child: const Text('Open Driver (temporary)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}