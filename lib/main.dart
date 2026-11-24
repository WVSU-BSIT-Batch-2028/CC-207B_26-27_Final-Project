import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'foodwise_theme.dart';
import 'screens/auth/splash_screen.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw Exception(
      'Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const FoodWiseApp());
}

class FoodWiseApp extends StatelessWidget {
  const FoodWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FoodWise',
      theme: FoodWiseTheme.light,
      home: const SplashScreen(),
    );
  }
}
