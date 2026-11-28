# LittleSteps

LittleSteps is a Flutter app that helps parents and other caregivers of children aged 0 to 5 plan simple play at home, note what they observe, and get play ideas suited to the child's age. It is the CC 207B final project of Thesis Titans, BSIT 3A, West Visayas State University.

The project includes the Android, iOS, web, Linux, macOS and Windows platform folders. Android is the main target and the one used for the demo; the other platforms build from the same code.

The app talks to the shared [LittleSteps API](https://github.com/Thesis-Titans/littlesteps-api). The [React web client](https://github.com/Thesis-Titans/littlesteps-react) of the same system is the visual reference.

## Team

| Member | GitHub |
|---|---|
| Mark Alvin Cadangin (lead) | @markalvincadangin |
| Justin Ace Ardeña | @Justin-Ardena |
| Vincent John Tamaño | @vincenttamano |
| Nherie C. Acebuche | @Lovelly143 |
| Mae Daniella Faith C. Benjamin | @faithbn |

## Core features

1. **Child profiles:** add a child by nickname and age band.
2. **Activity catalog:** browse and filter play activities by age band, domain, language and setting.
3. **Activity planning:** add activities to today's plan, mark them complete, and undo within 10 seconds.
4. **Milestone prompts:** record what the child has been seen doing. These are observations, not a diagnosis.
5. **Journal:** private notes per child.
6. **Storybooks:** search picture books and keep a family bookshelf.
7. **AI play ideas & weather hints:** catalog-first play suggestions matched to the child's age, time, and household materials, with opt-in guardrailed custom material adaptations (`Material adaptation` badge + safety notes for incompatible items), weather-aware indoor filtering via Open-Meteo, and deterministic catalog fallback when AI is unavailable.

"This week" summarizes completed activities and observations.

## Requirements

- Flutter 3.47 (stable) with Dart 3.13
- The LittleSteps API running locally (see its README)
- For Android: an emulator or physical device on API 34 or newer, and JDK 17 or 21
- For iOS or macOS: a Mac with Xcode
- For web: Chrome

## Setup and run

```bash
cd BSIT-3A/LittleSteps
flutter pub get
flutter run
```

`flutter run` picks a connected device; use `flutter devices` to list them and `flutter run -d chrome` (or another device ID) to choose one.

## Environment configuration (`--dart-define-from-file`)

Compile-time environment settings are centralized in `lib/config/app_config.dart` following Flutter's standard `--dart-define-from-file` convention:

| Profile | Command | Target |
|---|---|---|
| Android emulator / Web / Desktop | `flutter run --dart-define-from-file=config/local.emulator.json` | Uses `10.0.2.2` on Android AVD and `localhost` elsewhere |
| Physical Android phone (USB or Wireless Debugging) | `flutter run --dart-define-from-file=config/local.device.json` | Routes `localhost` through `adb reverse` (`5001` & `9099`) |
| Cloud / Production HTTPS | `flutter build appbundle --release --dart-define-from-file=config/production.json` | Switches to HTTPS Cloud Functions and live Firebase Identity Toolkit |

### Running or building for a physical Android phone (USB or Wireless Debugging)

1. Connect via USB **or** pair Android 11+ Wireless Debugging (`adb pair <ip:pair-port> && adb connect <ip:port>`).
2. Forward local Firebase Emulator ports to the device loopback:
   ```bash
   adb reverse tcp:5001 tcp:5001
   adb reverse tcp:9099 tcp:9099
   ```
3. Build or run with the device profile (use `--profile` or `--debug` for local emulators; `--release` enforces live HTTPS via `AppConfig.validateForRelease()` and requires `config/production.json`):
   ```bash
   flutter build apk --profile --dart-define-from-file=config/local.device.json
   adb install -r build/app/outputs/flutter-apk/app-profile.apk
   ```

### Android network security & release signing

- **Network security (`android/app/src/main/res/xml/network_security_config.xml`):** Release builds enforce HTTPS app-wide (`cleartextTrafficPermitted="false"`) and scope cleartext HTTP strictly to loopback (`localhost`, `127.0.0.1`, `10.0.2.2`) for local emulator routing. Debug builds (`src/debug/res/xml/network_security_config.xml`) permit local development HTTP and user CAs automatically.
- **Release signing (`android/app/build.gradle.kts`):** Copy `android/key.properties.example` to `android/key.properties` (gitignored) when signing a production bundle. Without `key.properties`, local verification builds sign cleanly with the debug key.

## Quality checks

Before opening a pull request:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Folder layout

```text
lib/
├── main.dart       # app entry point
├── config/         # compile-time environment configuration (AppConfig)
├── models/         # data classes with fromJson / toJson
├── routing/        # named routes
├── screens/        # one folder per feature
├── services/       # API client, offline cache, and domain services
├── theme/          # design tokens and Material 3 theme
└── widgets/        # shared widgets (shell, state views, cards, brand logo)
config/             # --dart-define-from-file JSON profiles
test/               # unit and widget tests
docs/               # AI usage log
android/ ios/ web/ linux/ macos/ windows/   # platform folders
```

## How we work

See [CONTRIBUTING.md](CONTRIBUTING.md) for branches, reviews and the AI usage log.

## Documentation

Product scope, design specification and API reference are in [littlesteps-docs](https://github.com/Thesis-Titans/littlesteps-docs).
