# Firebase setup (team guide)

Firebase is our deployed backend: sign-in (Authentication), the database (Firestore) and the AI assistant (Gemini through Firebase AI Logic).
We use the free **Spark** plan, so no payment card is needed.

The app reads its Firebase settings from a file called `firebase_config.json`.
**That file is never committed** (it is in `.gitignore`). The team leader shares it privately.
If a teammate does not have it yet, the app still runs: Firebase is skipped and the AI assistant shows its offline guidance.

## 1. Team leader: create the project (once)

1. Go to https://console.firebase.google.com and click **Create a project** (turn Google Analytics off, it is not needed).
2. In **Project settings > General > Your apps**, click the **Web** icon (`</>`) and register an app (for example `health360-web`). Skip Firebase Hosting for now.
3. Firebase shows a config block (`apiKey`, `appId`, `messagingSenderId`, `projectId`, `authDomain`, `storageBucket`).
4. Copy `firebase_config.example.json` to `firebase_config.json` in the project folder and paste those six values in.
5. Share `firebase_config.json` with the team **privately** (not in the repo, not in a public chat).
6. In **Project settings > Users and permissions**, add teammates (by their Google email) as **Editor** so they can see the console.

## 2. Everyone: run the app with the config

**Windows only, once:** Flutter needs *Developer Mode* to build projects that use plugins such as Firebase.
Run `start ms-settings:developers` in a terminal, switch **Developer Mode** on, then open a new terminal.
(If you see "Building with plugins requires symlink support", this is the fix.)

In the VS Code terminal, inside the project folder:

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=firebase_config.json
```

To use the normal Run button (F5), create `.vscode/launch.json` (it is ignored by Git, so each person makes their own):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Health360 (Chrome)",
      "request": "launch",
      "type": "dart",
      "deviceId": "chrome",
      "args": ["--dart-define-from-file=firebase_config.json"]
    }
  ]
}
```

## 3. Rules

- Never commit `firebase_config.json` or any API key. Check `git status` before every commit.
- Use sample data only. Do not put real patient information in Firestore.
- Web (Chrome) and Android/iOS work with Firebase AI Logic. **Windows desktop is not supported** for it, so demo on Chrome.
- If something looks wrong, open the browser console (F12) in Chrome and read the message that starts with `Firebase:`.

## 4. Pull request checklist for this setup

- [ ] `flutter pub add firebase_core` was run (it adds the package to `pubspec.yaml`).
- [ ] `firebase_config.json` is listed in `.gitignore` and does not appear in `git status`.
- [ ] The app starts with the config **and** without it.
- [ ] A teammate reviewed the pull request.
