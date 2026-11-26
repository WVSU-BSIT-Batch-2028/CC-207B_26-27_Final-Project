/// Non-web version of BrowserNotifier: browser notifications do not exist
/// here, so every method does nothing. See browser_notifier.dart.
class BrowserNotifier {
  BrowserNotifier._();

  /// False: this platform has no browser notifications.
  static bool get isSupported => false;

  /// False: nothing to ask for on this platform.
  static bool get isGranted => false;

  /// Always false here (there is no browser to ask).
  static Future<bool> requestPermission() async => false;

  /// False here: the app is assumed to be visible.
  static bool get pageHidden => false;

  /// Does nothing on this platform.
  static void show(String title, String body) {}
}
