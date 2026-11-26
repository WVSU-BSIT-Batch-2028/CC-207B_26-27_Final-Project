import 'package:flutter/material.dart';

const navy = Color(0xFF1D3F8C);
const wayBlue = Color(0xFF4A7FC1);
const blueSoft = Color(0xFFE4EDF9);
const gold = Color(0xFFF2B134);
const goldSoft = Color(0xFFFDF3DC);
const pageBg = Color(0xFFF3F7FC);
const ink = Color(0xFF1C2A44);
const muted = Color(0xFF5D6B85);
const line = Color(0xFFDBE4F1);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: wayBlue, primary: wayBlue, secondary: gold, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: pageBg,
    textTheme: Typography.blackMountainView.apply(bodyColor: ink, displayColor: ink),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: goldSoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: ink,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
