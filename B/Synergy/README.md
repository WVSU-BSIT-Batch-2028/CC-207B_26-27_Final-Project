# Synergy

1. Install the Flutter SDK and Google Chrome. Open a terminal in `B/Synergy`, the folder containing `pubspec.yaml`.
2. Install project dependencies with `flutter pub get`.
3. Start the app with `flutter run -d web-server --web-port=8080`. Open http://localhost:8080 in your normal browser. **Always use port 8080.** A different port starts with an empty save and cannot access your previous demo data.
4. Sign in with `budgetbuddy@demo.test`, `campusgrocer@demo.test`, or `printpal@demo.test`. All three use the password `demo123`.
5. To restore the sample data, expand **Demo controls · simulated partner** and select **Reset demo data**. If the button is unavailable, open Chrome DevTools on the app tab, choose **Application > Storage > Clear site data**, then reload. This removes your local demo changes.
6. Run the tests from the project folder with `flutter test --platform chrome`.
