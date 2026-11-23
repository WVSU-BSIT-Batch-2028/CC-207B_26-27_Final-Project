# WVSU WayFinder (Flutter)

The mobile client uses the same Supabase project, place IDs and data rules as the web app in the parent folder.

## Run

Requires Flutter 3.41+ / Dart 3.10+, Android (at least API 23; the installed Flutter SDK may require newer) or iOS 15.5+.

```bash
flutter pub get
flutter run
# For live campus data instead of the labeled demo fixtures:
cp env.example.json env.json
flutter run --dart-define-from-file=env.json
```

`env.json` is gitignored. Use public Supabase and map keys only. Android builds use Gradle 8.14.3, Android Gradle Plugin 8.11.1 and Kotlin 2.2.20 to support the installed Flutter toolchain. Use a full Java 21 JDK that includes `jlink`; a stripped runtime such as an IDE’s bundled JBR may not work. Select it with `flutter config --jdk-dir=/path/to/jdk21` if Flutter selects a newer incompatible JDK. iOS builds require full Xcode and CocoaPods; the Podfile sets the ML Kit minimum deployment target.

## Add my Schedule

1. On Home, tap **Add my Schedule**, then **Choose schedule file**.
2. Select the IUIS timetable or Certificate of Registration (COR) exported as a PDF, PNG, JPG or WebP (up to 20 MB; PDFs up to 20 pages).
3. Review the detected subjects, days, times, rooms and professors. Edit uncertain fields or uncheck unwanted meetings. Missing rooms remain unconfirmed and can be completed later, as allowed by the SQL schema. Classes can still be added manually.
4. Leave **Enable class reminders** on and save. Allow phone notification permission. On Android, allow exact alarms for timely reminders; without exact access, reminders can be delayed by Android.

PDF text and image/scanned-PDF recognition are processed locally. The document is not sent to a server. When saving, room codes can be checked against the configured campus directory; unrecognized rooms remain unconfirmed. Each selected document is copied from the picker cache into private app storage before recognition. Its preview remains visible on the import screen and under **My Schedule → Saved schedule files**, including when zero meetings were detected. The recognized text and reviewed classes are stored on this device. **Review classes from this file** reopens a saved upload after restarting the app. Previously uploaded reference images remain viewable and removable.

The parser supports row tables with section/number prefixes, course codes in different columns, subject titles in header-defined tables, weekday names or abbreviations (including MWF and TTh), 12/24-hour time ranges, OCR spacing around colons/AM/PM, and room/professor columns in different orders. Weekday headings and text geometry are used for weekly grids whose class blocks print time ranges. It reconstructs rows from PDF character positions and OCR text positions. Recognition is best effort: check every extracted meeting. The supplied screenshot shows the failed import result, not the original timetable, so its exact format is not yet verified. Grids with no printed times in class blocks and unusual layouts may require manual correction. **Review recognized text → Read these details** lets a student fix missed details without losing the selected file or starting over. Recognition never invents a class time from the visual height of a colored block. Image OCR requires the Android/iOS app; a browser preview cannot run native ML Kit.

Imports append to existing classes and skip duplicate meetings. A course meeting several days a week creates a class entry for each day. Times and reminders use Asia/Manila regardless of device timezone.

## Schedule SQL compatibility

`../supabase/migrations/0003_schedule.sql` matches the supplied schema. New class/upload IDs are UUID v4 values. Saved class records use `upload_id`, `start_time`, `end_time`, `tz`, `room_code_raw`, `room_place_id`, `professor_name` and `remind_minutes`. Old camelCase preferences still load, preserving existing classes and reminder IDs. Validation enforces the schema's subject/day/time/timezone/reminder constraints. Changes are persisted before the UI or reminders are notified; failed writes do not replace the current class list.

Saved upload metadata includes `id`, `storage_path` and `uploaded_at`, plus local display name and recognized text. The path resolves inside app-private storage. Imported classes reference that local upload ID. These are local equivalents of the SQL records: Supabase Auth, RLS and the private bucket policies are unchanged. The SQL bucket's 5 MB image-only limit applies to future authenticated cloud uploads, while this app's 20 MB PDF/image imports stay local. No student owner ID or anonymous cloud access is fabricated.

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

Verified for this branch: static analysis with no issues, 89 passing tests (including native PDF table/grid extraction, document persistence, zero-result recovery and SQL mapping), and a successful Android debug APK build using a full Java 21 JDK. iOS compilation and actual OCR/notification delivery on a phone still require device validation.
