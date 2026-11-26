# MatchBack

MatchBack is a Flutter web application for managing campus lost-and-found reports. It helps students submit lost or found-item reports, browse possible matches, submit ownership claims, and track claim status.

## Team

- Sven Catalan - project lead and Flutter/Firebase developer
- Ric Christian Bocatija
- Jesse Antoine Tacluyan
- Caryll Ann Calibjo

## Core Features

1. Report a lost item with validation and an optional photo.
2. Report a found item with validation and an optional photo.
3. Browse and filter lost and found reports.
4. Submit a claim and allow staff to approve, reject, prepare an item for collection, and confirm its return.
5. Generate AI-powered match suggestions from public item descriptions.
6. Track claim status: pending review, ready for collection, rejected, or returned to owner.

Also included: student and staff sign-in, and a staff-only view of the private identifying details on lost reports.

## AI Feature

MatchBack uses Firebase AI Logic with Gemini (`gemini-3.8-flash`) to compare public lost-item and found-item details. AI suggestions are clearly labeled and do not decide ownership. Users can dismiss any suggestion, and staff verify every claim.

Users can still browse reports and submit a claim manually if AI matching is unavailable (for example, a timeout or service error).

The AI feature does not send private identifying details, claimant names, or item storage locations.

## Technology Stack

- Flutter Web (Flutter 3.47.8, Dart 3.13.7)
- Firebase Authentication (anonymous sign-in for students, email and password for staff)
- Cloud Firestore for reports, claims, protected contact details, and user profiles
- Firebase AI Logic with the Gemini Developer API
- Firebase App Check
- `cloud_firestore` 7.1.0, `firebase_auth` 7.0.1, `firebase_core` 5.1.0
- `firebase_ai` 5.1.0, `firebase_app_check` 0.5.1
- `image_picker` 1.2.4, `google_fonts` 9.0.0, `cupertino_icons` 1.0.9
- `flutter_lints` 6.0.0 for static analysis

## Run Locally

1. Install Flutter 3.47.8 or a compatible Flutter SDK, Google Chrome, and the Firebase CLI.
2. Clone the repository and open the `BSIT 3-B/MatchBack` project folder.
3. Install the package dependencies:

```powershell
flutter pub get
```

4. Run against the normal Firebase project:

```powershell
flutter run -d chrome --web-port=5000
```

Use the fixed port `5000` so the App Check debug token stays the same between runs.

### Run locally with Firebase Emulator

The Emulator is the recommended way to test Firestore security rules without changing live Firebase data.

Start the Emulator in one terminal with `firebase emulators:start`. Keep it open, then run the app in a second terminal:

```powershell
flutter run -d chrome --web-port=5000 --dart-define=USE_FIREBASE_EMULATOR=true
```

Open the Emulator Suite at `http://127.0.0.1:4000`. The local app connects to Authentication on port `9099` and Firestore on port `8080`.

## Firebase Configuration

The app connects to the team's Firebase project through `lib/firebase_options.dart`. This file holds Firebase's public client configuration. It is not a secret: data is protected by Firestore security rules, not by hiding this key. No staff credentials, debug tokens, or private keys are stored in this repository.

Firestore rules are versioned in `firestore.rules`. For a live deployment, authenticate with the Firebase CLI, confirm the correct project in `.firebaserc`, then deploy deliberately:

```powershell
firebase deploy --only firestore:rules
```

Only deploy after reviewing the rules and confirming that live data follows the current schema. See `docs/firestore_security_test_plan.md` for the role-based test cases used with the Emulator.

## Staff Accounts

Staff accounts are created by an administrator in the Firebase console (Authentication). After creating the email-and-password account, copy its User UID and create this Firestore document:

```text
staff/{USER_UID}
  role: "staff"
```

The document ID must exactly match the Authentication User UID. Students provide a student ID and full name; staff-only controls are not displayed to student accounts. A matching ID and name do not verify a student's identity.

## Testing

Run the automated checks from the repository root:

```powershell
flutter analyze
flutter test
```

For the manual end-to-end workflow, use separate student and staff accounts in the Emulator:

1. Submit a lost-item report and a found-item report as a student.
2. Submit a claim for the found item as a student.
3. Approve the claim as staff and mark it ready for collection.
4. Confirm return to the owner as staff.
5. Verify that the student sees each status in **My Claims**.
6. Verify that a student cannot see staff-only controls.

Record results in `docs/firestore_security_test_plan.md` and capture relevant Emulator request logs as evidence.

## Known Limitations

- Student IDs are not verified against a school database.
- App Check uses a debug provider for local development. A production deployment would need a production provider such as reCAPTCHA Enterprise.
- On a machine whose App Check debug token is not registered, AI Match shows its fallback message instead of suggestions.
- Photos are handled in the app's report-image flow; storage and privacy constraints should be reviewed before a production release.
- AI suggestions can be wrong and always require staff verification.
