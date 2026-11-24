/// Browser (system) notifications for medicine reminders.
///
/// On the web this uses the browser's Notification API through
/// `package:web`. On other platforms (Windows desktop) a do-nothing version
/// is used, so the app still builds there; the in-app popup still works.
export 'browser_notifier_stub.dart'
    if (dart.library.js_interop) 'browser_notifier_web.dart';
