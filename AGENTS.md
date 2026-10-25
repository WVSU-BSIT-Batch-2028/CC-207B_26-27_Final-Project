# AGENTS.md: instructions for AI coding assistants

> **Members:** if you use an AI tool (Claude Code, Copilot, Cursor, ChatGPT...), send it these three things:
> 1. the prototype PDF (`Health360.pdf`),
> 2. the zip of this project,
> 3. this file,
>
> and start with this message (fill in the blanks):
>
> *"Read AGENTS.md first. I own the **<your module>** module. Match the prototype PDF for layout, labels and flow, and copy the
> styles and widgets already in the code. Write **one screen at a time** for me, fully commented, then walk me through it
> and give me practice changes, exactly as AGENTS.md section 2 says. Start with: **<screen name>**."*
>
> **AI assistants:** read this whole file before doing anything.

## 1. What this project is

Health360 is a Flutter app (patient side + doctor side) for the course **CC 207B Applications Development**
(West Visayas State University). A group of 5 builds one app; each member owns a module and must be able to
explain and live-modify their own code in an **Individual Code Defense**.

Requirements the app must meet (from the course):
- Flutter; UI follows the group's prototype (`Health360.pdf`).
- **At least 6 core features** (team of 5). A core feature = a user flow that takes input, changes state, and gives a result
  (e.g. book an appointment, request a refill). Login, splash and static pages do **not** count. The AI feature counts as one.
- At least one **AI feature** the end user interacts with: loading state, timeout/error handling with a fallback, AI output labelled as AI,
  user can override it, minimal personal data (Data Privacy Act of 2012, RA 10173).
- At least one **form with validation** and clear error messages.
- **Data persistence** (local storage or a cloud DB).
- **Async operations with visible loading, empty and error states.**
- Organised folders and **comments** that explain significant code.
- No API keys or secrets in the repo.

## 2. How AI assistants should help (writing screens is allowed, with explanations)

The team's current approach: **the AI may write a whole screen for a member, one screen at a time,** as long as the member
can understand, explain and change it. The course AI policy still applies: submitting code the member cannot explain is penalised
at the Individual Code Defense, and generating the whole app or large portions wholesale is not allowed. So follow these rules.

### 2.1 Scope per request
- Write **one screen per request** (plus the small widgets, model and service that screen needs). Do **not** generate a whole
  module or several screens in one go. When a screen is done, ask the member which screen is next.
- Build only what the prototype shows. If you add or change a feature, say so clearly.
- If the member has not given the prototype page for the screen, ask for it (or ask them to describe it).

### 2.2 Every screen must come with explanations
**In the code:**
1. A **file header comment**: what the screen is, what the user sees and can do, where its data comes from, and which shared widgets it uses.
2. A **comment on every class and method** saying what it does and why.
3. **Section comments** inside long `build` methods (for example `// Header`, `// List of appointments`, `// Empty state`).
4. A short comment on anything non-obvious (a validator, a `FutureBuilder`, an animation, a navigation result).
5. Keep it readable: small widgets, clear names, no clever tricks the member could not explain.

**In your reply after the code (a short guide, in plain language):**
1. **How it works**: the flow in 5 to 8 steps (what loads, what the user taps, what changes).
2. **Concepts used**: each Flutter concept (e.g. `StatefulWidget`, `ListView`, `Form`, `Navigator.push`, `Future`) with the line or widget where it appears.
3. **Where to change things**: how to change the text, colours (via tokens), navigation target, or add a form field.
4. **Practice changes**: 3 small tasks the member should do themselves before committing (like the live change the course may ask for:
   add a form field, change where a button navigates, rename a label).
5. **Likely defense questions**: 3 to 5 questions a teacher might ask about this screen, each with a short answer.
6. **AI Usage Log row**: a draft row (member, date, tool, what it was used for, what was generated) with **"What the member changed" left blank** for the member to fill in honestly.

### 2.3 Things the AI must still never do
- Never write the member's **individual reflection** or the **self and peer assessments**.
- Never skip the explanations above, even if the member says they are in a hurry.
- Never put secrets in code. Use `--dart-define` or a backend; keep keys out of Git.
- Do not invent packages or APIs. If unsure of a Flutter API, say so and point to the docs.
- Do not change files owned by other members without telling the member. Prefer small, focused changes.
- Remind the member: **commit it under your own name on a feature branch, change at least one thing yourself, and log it.**

## 3. Architecture and conventions

- State: plain `StatefulWidget` + services. No state-management package yet. Keep it simple.
- **Services hold data access.** Today they return mock data (`lib/services/*`). Screens call a service and never talk to storage directly.
  When the backend is ready (Firebase or MySQL API), replace the service internals and keep the method signatures.
- **Every async screen needs 3 states**: loading (`SkeletonBox`/`DashboardSkeleton`), empty (`EmptyState`), error (`ErrorState` with retry).
  See `lib/screens/patient/home/home_screen.dart` (`_load`, `_LoadStatus`) for the pattern.
- Forms: `TextFormField` + `Validators` (`lib/core/utils/validators.dart`) + `AppTheme.inputDecoration(...)`.
  See `lib/screens/profile/personal_info_screen.dart`.
- Navigation: tabs live in `PatientShell` / `DoctorShell` (IndexedStack). Full-screen pages use `Navigator.push` or a named route in
  `lib/core/routes/app_routes.dart`. When calling `Navigator.pushNamed`, do **not** add a type argument (it throws a cast error on our routes).
- File naming: `snake_case.dart`; one main widget per file; put screen-only widgets in a `widgets/` folder next to the screen.

## 4. Design system and consistency (follow the prototype)

**The prototype PDF is the source of truth for layout, labels and flow.** The code is the source of truth for styling.
Match each screen's structure, titles and button labels to the PDF, and build it with the existing tokens and widgets.

Do not hard-code colours, spacing or radii. Use:
- Colours: `AppColors`. The neutral ones (`mist`, `surface`, `border`, `skeleton`, `textPrimary`, `textMuted`, `navy`, `primary`) are **theme-aware getters** (light/dark),
  so they must **not** be used inside `const` expressions: drop `const` from that widget. Use `AppColors.brandNavy` for fills that must stay dark,
  and the fixed status colours (`success`, `warning`, `danger`) as usual. Dark mode is switched with `ThemeController.instance.setMode(...)`.
- Spacing / radius / shadow: `AppSpacing`, `AppRadius`, `AppShadows` (`lib/core/theme/app_tokens.dart`).
- Typeface: DM Sans (already in the theme). Do not set other fonts.

Reusable widgets in `lib/widgets/`:
`H360Card`, `H360Button` (`inverted` for dark surfaces), `StatusChip`, `SectionHeader`, `MenuTile`, `HeroPanel` (gradient panel),
`FadeSlideIn` (entrance animation), `SkeletonBox` / `DashboardSkeleton` / `EmptyState` / `ErrorState`, `showComingSoonSheet`,
`H360BottomNav`, `Sparkline`, `AppointmentStatusChip`. Check here before writing a new widget.

**Reference screens to copy from:**
| Need | Copy the pattern from |
|---|---|
| Dashboard / cards / loading, empty, error | `lib/screens/patient/home/home_screen.dart`, `lib/screens/doctor/doctor_home_screen.dart` |
| List of tappable rows | `lib/screens/profile/profile_screen.dart` (`MenuTile`) |
| Form with validation and saving | `lib/screens/profile/personal_info_screen.dart` |
| Toggles saved on the device | `lib/screens/profile/notifications_screen.dart` |
| Chat / AI with fallback | `lib/screens/ai/ai_assistant_screen.dart` |
| Tabs / navigation | `lib/screens/patient/patient_shell.dart`, `lib/screens/doctor/doctor_shell.dart` |

**Consistency checklist (use it when reviewing a pull request):**
- [ ] Layout, titles and labels match the prototype page.
- [ ] Only `AppColors` / `AppSpacing` / `AppRadius` / `AppShadows`; no hard-coded colours or font sizes for layout.
- [ ] Screen padding is `AppSpacing.md` (16) on the sides, sections separated with `SectionHeader`.
- [ ] Uses `H360Card`, `H360Button`, `MenuTile`, etc. instead of new look-alikes.
- [ ] Loading, empty and error states exist and were tested.
- [ ] Looks right in **light and dark mode**, on a **phone width and a wide browser window** (no overflow, nothing stuck to one edge).
- [ ] Still readable and not overflowing with **Text size: Large and Extra large** (Profile > App Theme). Body text is at least 14, small labels at least 13; no tiny gray text.
- [ ] Forms validate and show clear messages.
- [ ] Comments and file header are present; the author can explain every line.

## 5. Modules, owners and screens (from the prototype)

Replace the `ModulePlaceholder` for your tab in `patient_shell.dart` / `doctor_shell.dart` (search for `TODO(`).

| Module | Owner | Patient screens (Flutter) | Doctor screens |
|---|---|---|---|
| **Foundation, dashboards, AI, profiles** (done) | Ysai | Dashboard, AI assistant, Profile set, first-time guide | Landing page, Dashboard, Menu, Profile set |
| **Authentication** | Aecielle Cervantes | Get Started, Create Account, Input Information, Create Password, Insert Profile Picture, Account Created, Log In, Logout confirm/success | Splash/loading, Login |
| **Appointments** | Jahna Lagne | Overview, Book Appointment (set date and time), Appointment Details, Confirmation, Video Consultation (Google Meet link) | Appointment Overview (Upcoming/Past), Patient Overview, Patient Details, Video Consultation |
| **Prescriptions** | Carl Calotes | Prescriptions, Prescription Details, Set a Reminder, Prescription History, History Details | Prescriptions, Prescription Details, Add Prescription |
| **Records and Patients** | Gian Fernandez | Records Overview, Consultations, Consultation Details, Laboratory Results, Lab Result Details | Patients page, Patient Details, Patient Records, Lab Results, View Lab Results, Patient Prescriptions, Add Prescription, Prescription Added |

Ideas for core features to hit the 6 required (confirm as a team): book and track appointments, prescription reminders,
refill request, records search/filter, AI assistant (done), and one more of the team's choosing.

Open decision to confirm with the team: the **doctor side** is scaffolded in Flutter so both roles can be demoed in one app.
If the doctor portal is built in React for the Web System subject, the Flutter doctor screens can stay as a demo or be removed.

### 5.1 Requirements from the HCI validator feedback (do not miss these)

Five validators tested the prototype (a doctor, two nurses and two patients). Their feedback became requirements.
**Each owner must build their checklist below into their module**, or write the reason in Known Limitations if something cannot be done.
Tick the boxes as you finish. The "who said it" names are only for reference. See `docs/hci_feedback_actions.md` for the full table.

**Jahna Lagne: Appointments**
- [ ] Patient can **cancel and reschedule** an appointment from the patient side (Ian). A cancelled appointment shows the red *Cancelled* label.
- [ ] Show the **consultation fee** before the patient confirms a booking (Thaddeus).
- [ ] **Reminder one day before** the appointment: let the patient switch it on when booking (Luke). The Notifications history already has a sample "Appointment tomorrow" entry.
- [ ] **Video consultation**: add clear "How to join" steps (opens in Google Meet, may need the Meet app or the phone browser, allow camera and microphone) and a note that a **stable internet connection** is needed (Ivy, Luke).
- [ ] Add a **Contact Clinic** button or phone number in the appointment details (Luke). Use `ContactInfo` in `lib/core/constants/contact_info.dart`.
- [ ] **Search or filter doctors by specialty** in the booking flow (Luke).
- [ ] Use the shared **`AppointmentStatusChip`** (Confirmed / Pending / Cancelled) wherever appointments are listed, on both the patient and doctor side (Ian). Do not make a new one.
- [ ] Doctor side: a short **consultation notes** section after each appointment. Save it and show it to the patient under Records > Consultations (Ava). Coordinate with Gian.
- [ ] Keep the main buttons (for example Book Appointment) large and bright: use `H360Button` and do not shrink it (Ivy).

**Carl Calotes: Prescriptions**
- [ ] Show a short **confirmation message** when a reminder is set, so patients know it worked (Ian).
- [ ] **"Mark as Taken" history** that patients and doctors can both see (Ian). The Home medication checklist already saves taken doses per day in `DashboardService.setDoseTaken` (key `taken_doses_<date>` in shared_preferences). Build the history on that instead of creating a second store, and show it on the doctor's patient prescription screens.
- [ ] Doctor's **Add Prescription** form needs a **notes / instructions** field, e.g. "take after meals" (Ava). Show the notes in the patient's prescription details.
- [ ] **Refill request** flow (submit, then track the status) is one of our core feature ideas.
- [ ] Reminder text must be easy to read for older users: body text at least 14, nothing tiny (Ivy).

**Gian Fernandez: Records and Patients**
- [ ] **Lab results**: highlight **abnormal values** with colour **and** a label such as "High" or "Low" (not colour alone), and break the text into clear cards or rows instead of one packed block (Ian).
- [ ] Lab result details must not use small text: at least 14 (Luke).
- [ ] Doctor's **patient list**: add a **search bar and a filter** (for example by condition) (Ava).
- [ ] Make it clear whether the doctor can **request** lab tests or only **view** results: add a "View only" label or a Request action (Ava).
- [ ] Keep the **patient overview** with history, allergies, vitals, active prescriptions and lab results together in one place (Ava liked this).
- [ ] **Records > Consultations** shows the doctor's consultation notes (coordinate with Jahna).
- [ ] If you show vitals, reuse `VitalSign` and its readings (`lib/models/vital_sign.dart`) so the numbers match patient Home.

**Aecielle Cervantes: Authentication**
- [ ] **Fewer registration steps** or a clear **progress indicator** ("Step 2 of 5"); make the profile picture step **skippable** (Ivy and Thaddeus needed help at registration).
- [ ] Large, bright primary buttons (Ivy).
- [ ] Replace `RoleSelectScreen` (`lib/screens/role/`) with the real login. After login, route to `AppRoutes.patientShell` or `AppRoutes.doctorShell` by role. `confirmLogout` (`lib/screens/profile/logout_dialog.dart`) must also clear the session. Keep the demo switch until login works.
- [ ] Build **Change Password** (it is a "coming soon" row under Personal Information) and **Forgot password** (the Common Problems guide already mentions it).
- [ ] Collect only the personal data you need and show a short privacy note (Data Privacy Act of 2012, RA 10173).

### 5.2 Rules for everyone (from the same feedback)

- **Readability for older users:** body text at least 14, small labels at least 13, no small gray text. Use `AppColors.textMuted` and the theme. Test with **Profile > App Theme > Text size: Extra large**.
- **Status labels:** use `AppointmentStatusChip`; never rely on colour alone (always an icon or text).
- **Loading, empty and error states** on every async screen (already required).
- **First-time guide:** if your module adds a major feature, add or update a page in `lib/screens/onboarding/how_to_use_screen.dart` and tell Ysai.
- **Notifications:** new reminder types should add a toggle in `ProfileService.notificationOptions` and sample items in `loadNotificationHistory`, so they appear on the Notifications screen.
- **Help:** if your feature has a common failure (for example joining a video call), add a step list to `lib/screens/profile/troubleshooting_screen.dart`.

### 5.3 Deferred (do not build; list under Known Limitations or Future Enhancements)

- Online payment such as GCash (Thaddeus).
- Download or share lab results as a PDF (Thaddeus).
- Calendar view on the home page (Thaddeus).

## 6. How to add a screen (step by step)

1. Create a feature branch: `git checkout -b feature/<module>-<screen>`.
2. Create `lib/screens/<module>/` for your screens; models in `lib/models/`; a service in `lib/services/` (mock data first, with a simulated delay).
3. Ask the AI for **one screen** following section 2. Read the guide it gives you.
4. Do the practice changes yourself. Run the app in light and dark mode, phone and wide window.
5. Wire it in: replace your `ModulePlaceholder` in the shell, or add a named route.
6. Add a unit test for any non-trivial logic in `test/`.
7. Add your rows to `docs/topic_coverage_my_part.md` style tables (file + class + description) and your row to the AI Usage Log.
8. Commit with a meaningful message. Open a PR; a teammate reviews it with the checklist in section 4 before merging.

## 7. Git and secrets

- One feature branch per task; meaningful commit messages (graded from the history). Everyone contributes throughout, not only near the deadline.
- `.env`, `*.env`, `secrets.json`, keystores and Firebase config files are in `.gitignore`. Do not commit them.
- AI keys: `--dart-define=AI_API_KEY=...` or a backend. Never in source.

## 8. Definition of done for a screen

- Matches the prototype and passes the consistency checklist (section 4).
- Loading, empty and error states exist and were tested (use the demo scenario switch).
- Inputs validated with clear messages (for forms).
- Commented code; no unused files; `flutter analyze` shows no new errors.
- The author can explain every line and make a small live change (e.g. add a form field, change where a button navigates).
- AI Usage Log updated, with the "what the member changed" column filled in honestly.
