# WVSU WayFinder (Flutter)

The mobile client. It uses the same Supabase project, place IDs and data rules as the web app in the parent folder.

## What's here

- **Five tabs:** Home (with My Schedule), Map, Processes, Directory and AI Guide.
- **My Schedule:**
  - Timetable image upload through `image_picker`.
  - Weekly classes saved on the device with `shared_preferences`.
  - The next class in Asia/Manila time.
  - In-app reminders. Rescheduling or deleting a class cancels its old reminder.
- **Campus Map:** `flutter_map` with MapTiler raster tiles, walking routes over verified walkways, and *Use my location* (`geolocator`) or *Choose starting point*.
- **Processes, Directory (`faculty_directory`) and AI Guide:** the same queries and fallbacks as the web app.
- **Demo fixtures:** `assets/demo/*.json` must stay exact copies of `../src/data/demo/*.json`. A test checks this.

## Configure

```bash
cp env.example.json env.json   # SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, MAPTILER_KEY (public values only)
flutter run --dart-define-from-file=env.json
```

- **`env.json`:** it is gitignored. Without it the app runs on labeled demo data.
- **Permissions:** location is declared in `AndroidManifest.xml` and `Info.plist`.

## Test

```bash
flutter analyze
flutter test
flutter test --dart-define-from-file=env.json integration_live/   # manual read-only check against live Supabase
```

## Not yet available

- **Background notifications:** need `flutter_local_notifications` and a real device. Reminders currently fire only while the app is open.
- **Cloud schedule sync:** needs Supabase Auth.
