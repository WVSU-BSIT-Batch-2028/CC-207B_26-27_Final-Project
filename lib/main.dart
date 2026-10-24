import 'package:flutter/material.dart';
import 'package:websupark/theme/app_theme.dart';

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
      home: const PlaceholderScreen(),
    );
  }
}

// Temporary screen that only proves the project runs.
// It will be replaced by the real screens from the prototype.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'WEBSUPARK\nProject setup OK',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}