# WVSU WayFinder (Flutter)

The mobile client uses the same Supabase project, place IDs and data rules as the web app in the parent folder.

## Run

Requires Flutter 3.41+ / Dart 3.10+, Android API 23+ or iOS 15.5+.

```bash
flutter pub get
flutter run
# For live campus data instead of the labeled demo fixtures:
cp env.example.json env.json
flutter run --dart-define-from-file=env.json
```

`env.json` is gitignored. Use public Supabase and map keys only. Android builds use Gradle 8.14.3, Android Gradle Plugin 8.11.1 and Kotlin 2.2.20 to support the installed Flutter toolchain. Java 21 is recommended. Select it with `flutter config --jdk-dir=/path/to/jdk21` if Flutter selects a newer incompatible JDK. iOS builds require full Xcode and CocoaPods; the Podfile sets the ML Kit minimum deployment target.

## Add my Schedule

1. On Home, tap **Add my Schedule**, then **Choose schedule file**.
2. Select the IUIS timetable or Certificate of Registration (COR) exported as a PDF, PNG or JPG (up to 20 MB; PDFs up to 20 pages).
3. Review the detected subjects, days, times, rooms and professors. Edit uncertain fields or uncheck unwanted meetings. Missing rooms must be completed before saving. Classes can still be added manually.
4. Leave **Enable class reminders** on and save. Allow phone notification permission. On Android, allow exact alarms for timely reminders; without exact access, reminders can be delayed by Android.

PDF text and image/scanned-PDF recognition are processed locally. The document is not sent to a server. When saving, room codes can be checked against the configured campus directory; unrecognized rooms remain unconfirmed. Documents are discarded after parsing; reviewed classes are stored on this device using shared preferences. Previously uploaded reference images remain viewable and removable.

The parser supports row-based tables with course codes, weekday names or abbreviations (including MWF and TTh), 12/24-hour time ranges, and room/professor columns. It reconstructs rows from PDF character positions and OCR text positions. Recognition is best effort: check every extracted meeting. No real IUIS/COR sample was supplied with this change; grid-style timetables and unusual layouts may require manual correction. Image OCR requires the Android/iOS app; a browser preview cannot run native ML Kit.

Imports append to existing classes and skip duplicate meetings. A course meeting several days a week creates a class entry for each day. Times and reminders use Asia/Manila regardless of device timezone.

## Class reminders

Phone notifications include the subject, start time, classroom and professor, and repeat weekly, including when the app is closed. Editing or deleting a class updates or cancels its reminder. Android receivers restore scheduled reminders after a reboot. Notification permission is requested when saving an import with reminders enabled, or when tapping **Enable class reminders** in My Schedule; startup does not show permission prompts.

The schedule page shows permission and scheduling status. Android exact-alarm denial uses an inexact fallback. OS power restrictions, disabled notifications or a force-stopped app can prevent timely delivery. A maximum of 64 class reminders is scheduled, with a warning for additional classes. Reminders continue every week until you turn them off or delete the classes; there is no automatic semester end date. Desktop/web retain the existing in-app reminder fallback.

Dependencies are pinned for the verified APIs: [ML Kit text recognition 0.15.1](https://pub.dev/packages/google_mlkit_text_recognition/versions/0.15.1), [pdfrx 2.4.8](https://pub.dev/packages/pdfrx/versions/2.4.8), and [local notifications 19.5.0](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0).

## Other features

- Five tabs: Home, Map, Processes, Directory and AI Guide.
- Campus map with verified walking paths, room directions and optional device location.
- Directory/process/AI Guide queries and fallbacks shared with the web client.
- Demo fixtures in `assets/demo` must match `../src/data/demo` exactly.
- Cloud schedule sync is not configured; schedules remain on the current device.

## Validation

```bash
flutter analyze
flutter test
flutter build apk --debug
# Optional manual read-only check against live Supabase:
flutter test --dart-define-from-file=env.json integration_live/
```

Before releasing, verify an actual IUIS/COR export and a clear screenshot on a phone. Confirm notification delivery with the app closed, permission denial, an edited/deleted class and Android reboot behavior. Native OCR and actual notification delivery need a device; Dart tests cover parser/import review, persistence, timezone calculations and native scheduling through a fake backend.
