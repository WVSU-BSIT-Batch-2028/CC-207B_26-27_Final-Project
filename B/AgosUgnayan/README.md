# AgosUgnayan

A mobile and web app that helps smallholder farmers in Iloilo Province (starting with Leon) sell crops directly to local buyers, and shows both sides a fair reference price before they talk.

CC 207B Final Project (Applications Development and Emerging Technologies), WVSU, section B.

**Live app:** https://agosugnayan-cc207b.web.app (works on phones and computers; create an account to try it).

- **Client:** smallholder farmers in Leon, Iloilo
- **Users:** Farmer, Buyer (households and businesses), Admin (enters monthly reference prices)
- **Not included:** payments, cart, delivery, ratings, maps and language settings. The app connects people, and the deal happens in their own chat.

## Core features (team of 5 needs 6, AI included)

| # | Feature | Who uses it | Main files |
|---|---|---|---|
| F1 | **Crop Listings**: add, edit and delete crops with a validated form, Undo after delete | Farmer | `my_crops_screen.dart`, `crop_form_screen.dart`, `listing_service.dart` |
| F2 | **Marketplace**: browse, search, filter by crop and town, 20 at a time, listing details and farmer profile | Buyer | `marketplace_screen.dart`, `listing_detail_screen.dart`, `farmer_profile_screen.dart` |
| F3 | **AI Listing Assistant**: type a note like "50 kilos kamatis, 45 pesos" and Gemini fills in the crop form | Farmer | `ai_assistant_box.dart`, `ai_service.dart`, `ai_listing_suggestion.dart` |
| F4 | **Messages**: live chat between a buyer and a farmer | Both | `inbox_screen.dart`, `chat_screen.dart`, `message_service.dart` |
| F5 | **Buyer Requests**: buyers post what they need, farmers see it under Buyer Demand | Both | `my_requests_screen.dart`, `request_form_screen.dart`, `buyer_demand_screen.dart` |
| F6 | **Reference Prices**: monthly PSA farmgate prices with a 12-month chart and an offline copy; the admin downloads them from PSA OpenSTAT with one button (or types one in) | Farmer, Admin | `price_list_screen.dart`, `price_detail_screen.dart`, `admin_price_form_screen.dart`, `psa_service.dart` |

Also: **Following** (buyers follow crop listings or farmers, shown on two tabs) and **Profile** (your details, with Log out at the bottom). Login, Register, Following and Profile are supporting screens; they don't count as core features.

### Tabs per role

| Farmer | Buyer | Admin |
|---|---|---|
| My Crops, Demand, Prices, Messages, Profile | Market, Following, Requests, Messages, Profile | Prices, Profile |

## Tech stack

| Tool | Version |
|---|---|
| Flutter | 3.47.7 (stable) |
| Dart | 3.13.5 |
| Firebase | Auth (email/password), Cloud Firestore, AI Logic (Gemini) |
| Targets | Web and Android |

## Packages

| Package | Why we use it |
|---|---|
| `firebase_core` | Connects the app to our Firebase project; every other Firebase package needs it. |
| `firebase_auth` | Email and password login and registration. |
| `cloud_firestore` | Our online database for users, listings, requests, chats, following and prices. |
| `firebase_ai` | Calls Gemini for the AI Listing Assistant without putting an API key in the app. |
| `intl` | Formats pesos, dates and months, e.g. "₱45.00" and "Aug 2026". |
| `shared_preferences` | Saves the last loaded reference prices on the phone for offline use. |
| `fl_chart` | Draws the 12-month reference price chart. |
| `http` | Downloads farmgate prices from the PSA OpenSTAT API and sample crop photos from Wikipedia (both free, no key). |
| `image_picker` | Lets farmers pick their own crop photo on the web and on phones (free, BSD licence, by the Flutter team). |
| `image` | Shrinks that photo to an 800 px JPEG on the device before saving it (free, MIT licence). |

Everything we use is free: Firebase's Spark plan (no credit card), the Gemini free tier through Firebase AI Logic, and the public PSA OpenSTAT and Wikipedia APIs. See `docs/known-limitations.md` for the free-tier limits.

Navigation uses Flutter's built-in `Navigator.push` / `pop` (no routing package), the same way as in our class activities.

## Setup (each member, once)

1. Install Flutter stable and check it with `flutter doctor`.
2. Clone the team fork and open this folder (`B/AgosUgnayan`).
3. Get the packages:
   ```
   flutter pub get
   ```
4. Copy the placeholder Firebase settings so the code compiles:
   ```
   cp tool/firebase_options_example.dart lib/firebase_options.dart
   ```

### Option A: try everything without a Firebase project (emulator)

This runs a fake Firebase on your laptop with demo accounts and data. Good for coding and testing. You need Node.js and Java 21+.

```
npm install -g firebase-tools
firebase emulators:start --only auth,firestore --project demo-agosugnayan --config firebase.emulator.json
```

In a second terminal:
```
node tool/seed_emulator.mjs
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

Log in with `farmer@demo.ph`, `buyer@demo.ph`, `buyer2@demo.ph` or `admin@demo.ph`, password `demo1234`. The demo data includes a titled listing ("Pedro's Food Stall"), reserved, waiting, sold and expired orders, and a chat with order cards. To check the security rules for orders, stock and photos against the emulator (18 checks), run `node tool/rules_test.mjs` after seeding. The emulator forgets everything when you stop it; run the seed script again after restarting. The AI assistant does not work in the emulator, so it shows its fallback message, which is a good way to demo the fallback.

### Option B: the real Firebase project

1. The team leader creates the Firebase project in the Firebase console and:
   - turns on **Authentication → Email/Password**,
   - creates a **Cloud Firestore** database,
   - turns on **AI Logic** with the **Gemini Developer API** (free tier),
   - adds every member's Google account to the project.
2. Each member connects their laptop:
   ```
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=android,web
   ```
   This creates `lib/firebase_options.dart` and `android/app/google-services.json`. Both are in `.gitignore` because they hold our Firebase keys. **Never commit them.**
3. Upload the security rules and indexes once (team leader):
   ```
   firebase deploy --only firestore:rules,firestore:indexes --config firebase.emulator.json --project <your-project-id>
   ```
4. Make the admin account: register normally, then in the Firebase console open `users/<that user's id>` and change `role` to `admin`. The app never lets anyone pick admin.
5. Run the app:
   ```
   flutter run -d chrome
   ```
   If the first screen says **Firebase is not set up yet**, repeat step 2.

### Deploy the web app (Firebase Hosting)

The live app is at https://agosugnayan-cc207b.web.app. Only someone added to the Firebase project can deploy.

1. Add Hosting to your `firebase.json` (it is gitignored, because `flutterfire configure` writes it). Add these two parts next to the `"flutter"` part:
   ```json
   "hosting": {
     "public": "build/web",
     "ignore": ["firebase.json", "**/.*"],
     "rewrites": [{ "source": "**", "destination": "/index.html" }]
   },
   "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" }
   ```
2. Build for the real Firebase project (never with `USE_EMULATOR`):
   ```
   flutter build web --release --no-web-resources-cdn
   ```
3. Deploy:
   ```
   firebase deploy --only hosting --project agosugnayan-cc207b
   ```
   If you changed `firestore.rules` or `firestore.indexes.json`, deploy those too: `firebase deploy --only firestore:rules,firestore:indexes --project agosugnayan-cc207b`.

The built app contains the Firebase **web** API key. That is normal for every Firebase web app and not a secret: the data is protected by `firestore.rules` (you must be logged in, you can only change your own things, only the admin writes prices). Never commit `lib/firebase_options.dart`, `android/app/google-services.json` or `firebase.json`.

## How we work

- One feature at a time, each on its own branch: `feature/<short-name>`.
- Commit under your own GitHub account, in small commits that say what and why.
- Before every commit:
  ```
  dart format .
  flutter analyze
  flutter test
  ```
  Also check that the diff has no keys or passwords.
- Every pull request is reviewed and approved by another member before merging.
- Add one line to `docs/ai-usage-log.md` for every AI-assisted change, and your rows to `docs/topic-coverage-matrix.md` after your feature.

GitHub Actions runs format, analyze and test on every push and pull request (`.github/workflows/ci.yml` at the repo root).

## Folders

```
lib/
  main.dart        App start, error catching, Firebase (or emulator) connection
  screens/         One file per full page; home_screen.dart holds the bottom tabs
  widgets/         Reusable pieces (cards, buttons, form fields, AI box, state view)
  models/          Data classes with fromMap/toMap
  services/        The only code that talks to Firebase and the AI
  utils/           Theme, strings, constants, validators, formatting, logger
assets/fonts/      Inter and Barlow Condensed from the Figma design (Open Font License)
test/              Unit and widget tests
docs/              Checklist, AI Usage Log, Topic Coverage Matrix, AI Feature Spec, limitations, usability review
tool/              Placeholder Firebase settings (for CI) and the emulator seed script
firestore.rules    Who can read and write what in Firestore
```

## Firestore data

| Collection | What's in it |
|---|---|
| `users/{uid}` | name, email, role (farmer, buyer, admin), town, about, createdAt, consentAt |
| `users/{uid}/following/{targetId}` | type (listing or farmer), title, subtitle, createdAt |
| `listings/{id}` | farmerId, farmerName, crop, quantity, unit, price, town, harvestDate, description, aiAssisted, createdAt |
| `requests/{id}` | buyerId, buyerName, crop, quantity, unit, targetPrice, town, neededBy, notes, createdAt |
| `chats/{uidA_uidB}` | participants, names, lastMessage, lastMessageAt |
| `chats/{id}/messages/{id}` | senderId, text, createdAt |
| `prices/{crop}_{yyyy-MM}` | crop, month, price, enteredBy, enteredAt |

## Design

Colors, sizes and fonts come from the v3 row of our Figma file: https://www.figma.com/design/6iDTiJCeqccRiDczkkpmsF/AgosUgnayan-Prototype, and live in `lib/utils/theme.dart`. Shared text (buttons, errors, validation messages) is in `lib/utils/strings.dart`; text used by only one screen is written in that screen so it's easy to find.
