# Health360 · Flutter app (v0.5)

Healthcare for the Future: a patient + doctor app prototype for CC 207B.
This version contains the **design foundation**, the **patient and doctor dashboards**,
the **AI assistant**, and **both profiles**. Teammates plug their modules into it.

## Run it

This zip has the Dart source only. Generate the platform folders once:

```bash
flutter create . --project-name health360 --org edu.wvsu --platforms web,windows
flutter pub get
flutter run -d chrome
flutter test
```

Flutter 3.22+ (Dart 3.3+) is required. Android/iOS can be added later with `--platforms android,ios`.

## Accounts and login

- The app opens on **Login**. Patients create their own account with **Register**.
- **Doctor accounts are created by the clinic administrator** in the Firebase console
  (Authentication > Add user, then a `users/{uid}` document with `role: "doctor"`).
  The security rules reject any self-registration as a doctor.
- After login the app opens the patient or doctor side from the account's role. **Log Out** is in Profile.
- Developers only: `--dart-define=START_ROUTE=/patient` (or `/doctor`) skips login to check layouts;
  data does not load without a signed-in account.

## What is built

| Area | Screens |
|---|---|
| Design foundation | Theme, colour/spacing/radius tokens, shared widgets, role-aware bottom nav |
| Patient | Dashboard (next appointment, quick actions, health at a glance, today's medications), AI assistant. Tap a health card for its trend, data source and an "Add a reading" form |
| Doctor | Landing page (today's schedule, quick overview, today's appointments with Confirmed / Pending / Cancelled labels), Dashboard (6 shortcuts, recent activity), slide-out menu |
| Profiles (both) | Profile with the same four rows for patient and doctor: Personal Information (validated form, saved in Firestore, with Change Password), Notifications (settings + history; the newest also show on Home with "Mark as done"), App Theme (**dark mode** and **text size**), Help & Support (How to Use guide, Common Problems, FAQs) |
| First-time guide | "How to use" pages shown once per role; reopen from Profile > Help & Support |
| Modules | Appointments (booking, edit/cancel requests, video visits), Prescriptions (reminders, refills, doses taken, openFDA reference), Records (consultation notes, lab results), doctor Patients, Prescriptions and Lab Results entry. All data in Cloud Firestore |

## Demo controls (for the presentation)

- **Long-press the avatar** on a Home screen: switch every list between Normal / Empty / Error.
- **⋮ menu in the AI screen**: *Simulate AI outage* shows the offline fallback.
- **Health at a Glance** shows 7 days of readings marked *Sample*, plus the patient's own readings
  (only the patient's own readings are saved to Firestore and shown to the doctor).
- **Loading**: Chrome DevTools (F12) > Network > *Slow 4G*, then open any list.
- **Profile > App Theme**: switch Light / Dark and Text size (saved on the device).
- **First-time guide** shows once per role. To see it again, open Profile > Help & Support > How to Use Health360.
- **Pull down** on a Home screen to refresh. Tap a medication to mark it taken (saved for today).

## Project structure

```
lib/
  main.dart, app.dart
  core/
    theme/      app_colors (light + dark palettes), app_tokens, app_theme, theme_controller
    routes/     app_routes (named routes, START_ROUTE)
    utils/      date_format, validators
  models/       plain data classes
  services/     one service per module; Firestore reads/writes (see firestore.rules)
  widgets/      shared UI (card, button, chip, hero panel, menu tile, skeleton/empty/error, bottom nav ...)
  screens/
    patient/    patient_shell + home/
    doctor/     doctor_shell, home, dashboard, drawer
    profile/    profile, personal info, notifications, help & support, theme sheet (both roles)
    ai/         AI assistant
    shared/     module_placeholder
test/           AI fallback tests
```

## Colours and dark mode (read before styling)

`AppColors.mist / surface / border / skeleton / textPrimary / textMuted / navy / primary` follow light/dark mode,
so they are **getters, not constants**. Do not use them inside a `const` widget; if you get
*"Not a constant expression"*, remove `const` from that widget. Use `AppColors.brandNavy` for a fill that must stay dark
(for example a circle behind a white icon). Status colours and `heroGradient` are fixed.

## For teammates

1. Read FIREBASE_SETUP.md to run the app with Firebase on your computer.
2. Work on a feature branch; open a pull request reviewed by a teammate.
3. Log any AI help in the team's AI Usage Log.
4. **Never commit API keys.** `.env` and key files are in `.gitignore`.
