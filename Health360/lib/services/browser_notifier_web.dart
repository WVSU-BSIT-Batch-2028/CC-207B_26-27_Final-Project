import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web version of BrowserNotifier, using the browser's Notification API.
///
/// The browser asks the patient once ("Allow notifications?"). If they
/// allow it, a system notification appears when a medicine is due while the
/// Health360 tab is in the background. The tab must still be open: closed
/// tabs cannot run reminders without a server (see Known Limitations).
///
/// Every call is wrapped in try/catch: some browsers (or private windows)
/// do not support notifications, and the app must never crash because of it.
class BrowserNotifier {
  BrowserNotifier._();

  /// True if this browser has the Notification API.
  static bool get isSupported {
    try {
      web.Notification.permission;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True once the patient has allowed notifications for this site.
  static bool get isGranted {
    try {
      return web.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// Shows the browser's "Allow notifications?" prompt (only if the patient
  /// has not answered yet). Call it from a tap, which browsers require.
  /// Returns true when notifications are allowed.
  static Future<bool> requestPermission() async {
    try {
      final current = web.Notification.permission;
      if (current == 'granted') return true;
      if (current == 'denied') return false;
      final answer = await web.Notification.requestPermission().toDart;
      return answer.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// True when the Health360 tab is not the one being looked at.
  static bool get pageHidden {
    try {
      return web.document.hidden;
    } catch (_) {
      return false;
    }
  }

  /// Shows a system notification, if the patient allowed them.
  static void show(String title, String body) {
    if (!isGranted) return;
    try {
      web.Notification(
        title,
        web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'),
      );
    } catch (_) {
      // Not supported here: the in-app popup is still shown.
    }
  }
}
