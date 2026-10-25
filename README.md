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

## Checking both sides (no login yet)

- The app opens on a **role gate**: *Continue as Patient* or *Continue as Doctor*.
- From either **Profile** tab, tap **Switch view (demo)** to jump to the other side. **Log Out** returns to the gate.
- Skip the gate while developing:
  `flutter run -d chrome --dart-define=START_ROUTE=/patient` (or `/doctor`).

## What is built

| Area | Screens |
|---|---|
| Design foundation | Theme, colour/spacing/radius tokens, shared widgets, role-aware bottom nav |
| Patient | Dashboard (next appointment, quick actions, health at a glance, today's medications), AI assistant. Tap a health card for its trend, data source and an "Add a reading" form |
| Doctor | Landing page (today's schedule, quick overview, today's appointments with Confirmed / Pending / Cancelled labels), Dashboard (6 shortcuts, recent activity), slide-out menu |
| Profiles (both) | Profile with the same five rows for patient and doctor: Personal Information (validated form, saved locally, with Change Password), Notifications (settings + history), Language, App Theme (**dark mode** and **text size**), Help & Support (How to Use guide, Common Problems, FAQs) |
| First-time guide | "How to use" pages shown once per role; reopen from Profile > Help & Support |
| Placeholders | Appointments, Prescriptions, Records (patient); Appointments, Patients (doctor). Marked with `TODO(owner)` |

## Demo controls

- **Long-press the avatar** on a Home screen: switch data between Normal / Empty / Error.
- **⋮ menu in the AI screen**: *Simulate AI outage* shows the offline fallback.
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
  services/     dashboard_service, doctor_service, profile_service, ai_assistant_service  (mock data + local storage)
  widgets/      shared UI (card, button, chip, hero panel, menu tile, skeleton/empty/error, bottom nav ...)
  screens/
    role/       role gate (temporary)
    patient/    patient_shell + home/
    doctor/     doctor_shell, home, dashboard, drawer
    profile/    profile, personal info, notifications, help & support, language/theme sheets (both roles)
    ai/         AI assistant
    shared/     module_placeholder
test/           AI fallback tests
docs/           topic coverage + AI usage log starters
AGENTS.md       instructions for AI tools (read this first if you use one)
```

## Colours and dark mode (read before styling)

`AppColors.mist / surface / border / skeleton / textPrimary / textMuted / navy / primary` follow light/dark mode,
so they are **getters, not constants**. Do not use them inside a `const` widget; if you get
*"Not a constant expression"*, remove `const` from that widget. Use `AppColors.brandNavy` for a fill that must stay dark
(for example a circle behind a white icon). Status colours and `heroGradient` are fixed.

## For teammates

1. Read **AGENTS.md**. It explains the rules, the design system, where your module goes, and the checklist of feedback items each owner must cover (section 5.1). If you use an AI tool, send it the prototype PDF, this project's zip and AGENTS.md; it will write one commented screen at a time and explain it to you.
2. Work on a feature branch; open a pull request reviewed by a teammate.
3. Log any AI help in the AI Usage Log (`docs/ai_usage_log_entry.md` has the format).
4. **Never commit API keys.** `.env` and key files are in `.gitignore`.
