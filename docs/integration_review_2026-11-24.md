# Integration review and fixes (2026-11-24)

Reviewed: the GitHub `main` zip, the `firestore.rules` Ysai published, and the
handoff briefing. A Flutter SDK could not be installed in the review
environment, so this was a static review (imports, constructors, service
methods and enum values were cross-checked by script; logic was read by hand).
**Run `flutter analyze` and `flutter test` before merging.**

## Why teammates see hundreds of errors

`main` itself is consistent: every import resolves, every service method that
a screen or test calls exists. The 883 issues in the screenshot come from a
branch (`feature/patient-appointments`) that has the new test
`test/patients_service_mapping_test.dart` but an old
`lib/services/patients_service.dart` without `toPrescription`. That happens when
a branch was started from an old `main` and only some files were merged.

Fix on each teammate's computer:

```
git stash                # keep unfinished work aside
git checkout main
git pull
git checkout feature/<your-branch>
git merge main           # or: git rebase main
git stash pop
flutter pub get
flutter analyze
```

Ysai's own folder is 8 commits behind `origin/main`. Before pulling, copy
`docs/ai_feature_specification.md` somewhere safe (it exists only locally).

## API / Firestore integration status

| API / collection | Owner | Status before | Now |
| --- | --- | --- | --- |
| Firebase Auth (email/password) | Aecielle | Done, patient-only registration (matches the rules) | No change; profile cache now refreshes after a name change |
| `users` | Aecielle | Done | No change |
| `appointments` | Jahna | Done in Firestore | Updates now write only changed fields (see fix 2) |
| Patient Home next appointment | Jahna / Ysai | Sample "Dr. Maria Santos" | Reads the patient's next upcoming appointment |
| Doctor Home + Dashboard | Jahna / Ysai | Sample data | Today's schedule, patient count, prescription and lab counts, recent activity from Firestore |
| `prescriptions`, `refillRequests`, `reminders`, `doseLogs` | Carl | Done in Firestore, doctor approve/decline done | Refill re-request after approval now gives a clear message |
| openFDA drug label | Carl | Done (key optional via `--dart-define`) | `OPENFDA_API_KEY` slot added to `firebase_config.example.json` |
| RxNav | Carl | Not used (optional) | Not added |
| `consultations`, `labResults`, `patientProfiles` | Gian | Read from Firestore; doctor writes consultation notes | Add Prescription frequency bug fixed |
| Doctor Prescriptions screen | Gian | Built but not reachable (menu said "coming soon") | Opened from the drawer, the Home tile and the Dashboard |
| `vitalReadings` | Ysai | Readings saved only on the device, so the doctor never saw them | Saved to Firestore; doctor's Patient Records shows them |
| Gemini via Firebase AI Logic | Ysai | Done | No change |

Still not written by any screen (seed them in the console, or list as a known limitation):
`labResults` (doctor has no "add lab result" form) and `patientProfiles`
(age, sex, conditions, allergies).

## Fixes made

1. **Add Prescription saved the wrong frequency** (`add_prescription_screen.dart`).
   The dropdown keys were one off: "Once a day" saved `timesPerDay: 2`, so the
   patient saw "2x a day". Keys now match the text; "Take as needed" was removed
   because it cannot be stored as a number per day.
2. **Appointment updates could be rejected by the rules** (`appointment_service.dart`).
   Every update rewrote all fields. A timestamp written on Windows (microseconds)
   and re-written from Chrome (milliseconds) counts as a changed field, which
   `affectedKeys().hasOnly(...)` rejects. Now only the fields that really changed
   are written.
3. **AppointmentService crashed without Firebase** (START_ROUTE bypass): the
   Firestore instance was read when the service was created. It is now a getter,
   like the other services.
4. **Refill after an approved refill showed "Permission denied"**
   (`prescription_service.dart`). The rules only let a patient re-send a
   declined request; the service now says the refill was already approved.
5. **Personal Information kept showing the old name** after saving
   (`profile_service.dart`, `auth_service.dart`): the cached `users/{uid}` copy is
   cleared after the save.
6. **Patient Home** (`dashboard_service.dart`): next appointment from
   AppointmentService; vitals added by the patient go to `vitalReadings`; no
   fake 1.1 s delay; the sample name "Jahna" removed. Saving a reading shows an
   error message if Firestore refuses it (`vital_detail_sheet.dart`).
7. **Doctor Home, Dashboard and drawer** (`doctor_service.dart`,
   `doctor_home_screen.dart`, `doctor_dashboard_screen.dart`, `doctor_shell.dart`):
   real data, the doctor's own name, and Prescriptions / Records / Lab Results
   open real screens instead of "coming soon".
8. Email validation accepted only 2 to 4 letter endings (`.com`); now any
   ending of 2 or more letters. Removed a leftover `BOOKING DEBUG` print.
   `windows/flutter/ephemeral/` added to `.gitignore`. `firestore.rules` added to
   the repo so it is versioned.

## Firestore rules

The published rules already cover every query above, including the new ones:
`vitalReadings` create (patientId = uid) and list, and the doctor's `count()`
queries on `prescriptions` and `labResults` (allowed by `isDoctor()`). No rule
change is required.

## How to test after pulling

1. `flutter pub get`, `flutter analyze`, `flutter test`.
2. Patient: book an appointment, then open Home: the card shows it (Pending).
3. Patient: Home > tap Heart Rate > add a reading. Doctor: Patients > that
   patient > View full record: the reading is under vitals.
4. Doctor: Home shows today's count and the patient's name; Menu >
   Prescriptions opens the list; Add Prescription with "Once a day" shows
   "1x a day" on the patient's side.
5. Doctor confirms the appointment from Chrome after the patient booked from
   Windows desktop (checks fix 2).

## Draft AI Usage Log row (fill in the last column yourself)

| Member | Date | AI tool | What it was used for | What was generated | What the member changed |
| --- | --- | --- | --- | --- | --- |
| Ysai | 2026-11-24 | Claude | Integration review of teammates' modules against the Firestore rules, and fixes for the bugs found | Changes in the files listed under "Fixes made" and this review | |

## Round 2: data sources, doctor name, demo removal

### Where records come from

There is no hospital system to import from, so the doctor creates every record in the app:

| Record | Who writes it | Where in the app | Collection |
| --- | --- | --- | --- |
| Consultation notes | Doctor | Patients > patient > Add Consultation Notes | `consultations` |
| Lab results (new) | Doctor, from the laboratory's report | Patients > patient > View full record > Lab Results > Add Lab Result | `labResults` |
| Prescriptions | Doctor | Patients > patient > Prescriptions > Add Prescription | `prescriptions` |
| Vitals | Patient | Home > tap a health card > Add a reading | `vitalReadings` |

The patient sees consultations and lab results in Records. Saved lab results
are view only. Future work: import results from a laboratory or hospital
system (for example HL7 FHIR).

### Fixes

- **Prescribed by showed "Doctor".** The name came from the Auth display name,
  which doctor accounts made in the console do not have. It now comes from
  `users/{uid}.fullName`. Prescriptions already saved as "Doctor" show the real
  name, looked up from the doctor's account. The empty phone line is hidden.
- **New Add Lab Result screen** (`add_lab_result_screen.dart`,
  `lab_test_option.dart`, `PatientsService.addLabResult`). Five common tests
  with their values, units and normal ranges. High / Low flags are worked out
  from the range.

### Demo features removed

- Long-press avatar Normal / Empty / Error switch (`demo_scenario_sheet.dart`
  deleted, `DemoScenario` removed from every service).
- AI screen "Simulate AI outage (demo)".
- Set Reminder "Preview reminder (demo)".
- 7-day sample vitals. Health cards show "Add a reading" until the patient adds one.
- Fake notification history. It is now built from the user's appointments,
  refill answers and new records (doctor: bookings, change requests,
  cancellations, refill requests).
- Sample profile names ("Jahna Reyes", "Dr. Michael Santos"), the "Demo doctor
  profile" label and the made-up "next available" times in booking.
- "Coming soon" sheets (doctor Live Chat, Activity "View All"). Unused files
  deleted: `coming_soon_sheet.dart`, `role_select_screen.dart`,
  `module_placeholder.dart`.

How to show the empty, error and loading states now: see "Showing each state"
in README.md.

### Still a known limitation

- Medicine reminders are saved but no alert pops up at the reminder time
  (that needs a notifications package; listed as future work).
- `patientProfiles` (age, sex, conditions, allergies) has no screen that writes it.

## Round 3: demo controls restored, patient info form

- **Restored for the presentation:** the long-press avatar Normal / Empty /
  Error switch (all services), the AI screen's "Simulate AI outage", and the
  7-day sample vitals (labelled "Sample"). Only the patient's own readings are
  saved to Firestore, so the doctor never sees sample numbers. The other round 2
  removals stay removed.
- **New Edit Patient Info** (doctor: Patients > patient > Edit Patient Info,
  `edit_patient_info_screen.dart`, `patient_profile.dart`,
  `PatientsService.fetchPatientProfile / savePatientProfile`). Saves age, sex,
  contact number, main condition, Active / History status, allergies,
  immunizations and medical history to `patientProfiles/{uid}`. Works with the
  published rules (doctors write, the patient and doctors read).
  Tests: `test/patient_profile_test.dart`.

## Round 4: medicine reminders that pop up

- **In-app reminder** (`reminder_scheduler.dart`, `reminder_due_dialog.dart`,
  started by `patient_shell.dart`): while the patient side is open, saved
  reminders are checked every 30 seconds. At the time, an "It's time to take"
  popup offers **Taken** (marks today's dose, Home updates) or **Remind me in
  10 minutes**. "Every 8 hours" means 12:00 AM, 8:00 AM and 4:00 PM; a custom
  time is skipped if the dose was already marked taken that day.
- **Browser notification** (`browser_notifier*.dart`, package `web`): turning
  on "Enable Notifications" asks Chrome for permission. If allowed, a system
  notification also appears when the Health360 tab is in the background.
  Windows desktop uses a do-nothing version, so it still builds.
- Limitation: the app (a browser tab) must be open. Reminders while it is
  closed need push notifications sent by a server (future work).
- Tests: `test/reminder_schedule_test.dart`.
- Run `flutter pub get` after pulling (new `web` dependency in pubspec.yaml).

## Round 5: clinic hours, profile in Firestore, doctor details, demo data

1. **Clinic hours** (`core/constants/clinic_hours.dart`): bookings and change
   requests only Monday to Saturday, 8:00 AM to 4:30 PM (last start). Sundays
   are greyed out in the calendars; the service checks it too.
   Tests: `test/clinic_hours_test.dart`.
2. **Personal Information in Firestore**: mobile, birth date, gender and
   address are saved in `users/{uid}` (allowed by the rules), with an error
   message if saving fails.
3. **Doctor details from Firestore**: the hard-coded list of 5 doctors was
   removed from `booking_doctor_service.dart`. Specialty, consultation type
   and fee are fields of each doctor's `users` document (see
   `docs/demo_data_setup.md`, step 1). Tests: `test/booking_doctor_service_test.dart`.
4. **Demo data checklist**: `docs/demo_data_setup.md`.
5. **Linked patient ID removed**: every collection uses the patient's uid.
   `firestore.rules` is simpler (no extra `get()` per check). **Publish the new
   rules** (Firebase console > Firestore > Rules > paste > Publish).
6. **Bug fixed: refills could never be requested.** The refill date was the
   last day of the course, when the prescription is already finished and the
   Request Refill button is gone. New prescriptions open the refill 2 days
   before the course ends.

## Round 6: first-time guide before the dashboard

- New accounts see the "How to use" guide in place of the dashboard; "Get
  started" or "Skip" opens the dashboard (patient and doctor shells,
  `how_to_use_screen.dart` `onFinished`).
- "Seen" is saved per account (`guideSeen: true` in `users/{uid}`, plus a copy
  on the device), so each new account sees it once, even on a shared laptop.
- Existing accounts see it one more time after this update (the old flag was
  per device, not per account).

## Round 7: notifications on Home, Language removed

- **Notifications card on both Home screens** (`widgets/notifications_preview.dart`):
  the number of new notifications and the 3 newest, each with **Mark as done**
  (a green "Done" check afterwards). Same data and category switches as
  Profile > Notifications; "See all" opens that screen. Reloads with Home.
- **Language removed from Profile** (only English existed). Profile now has
  four rows: Personal Information, Notifications, App Theme, Help & Support.
- Home reloads when its tab is opened again (new prescriptions show at once).
- All popups use standard widths (`AppSizes`, `DialogFrame`) and one dialog theme.
- Records and Patients screens keep a visible scroll bar at the window edge.
