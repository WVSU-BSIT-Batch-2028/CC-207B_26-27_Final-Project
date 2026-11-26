# Synergy Flutter roadmap

Build one exchange that a founder can finish with a partner startup. **BudgetBuddy** needs people to test its onboarding and can give product feedback. **Campus Grocer** can recruit testers and wants feedback on its checkout. A successful build lets the two startups find each other, agree on a test, confirm the work and exchange private reviews. Startup founder is the only account role.

Build a **local-first Flutter Web app with no backend**. All data is saved in the browser on the demo laptop, and the AI tag suggestions come from a small model bundled with the app. During the demo you stay signed in as BudgetBuddy in **one browser tab**. Campus Grocer is a sample startup. A clearly labeled **Simulate Campus Grocer …** button performs Campus Grocer's next step through the same Dart rules a real founder would use.

**Why no backend.** Page 2 of the CC 207B brief allows local storage for persistence and on-device machine learning for the AI feature. Supabase was only an earlier recommendation, not a requirement. The tradeoff: founders on different laptops can't exchange data. List that as a limitation and name a shared backend as the next improvement.

### Keep the code simple · team rules

1. **One save slot.** All data is saved as one JSON string. Every change goes through `store.update()`.
2. **Two lists.** The app keeps `startups` and `exchanges`. Terms, milestones and reviews live inside each exchange.
3. **All rules in one file.** `rules.dart` decides who can do what. Screens never decide on their own.
4. **Screens update themselves.** One `AppStore` notifies every screen when data changes.
5. **No code for problems a one-tab app can't have.** No versioned terms, no race handling, no late-result handling.
6. **One owner per file.** Each member mostly edits their own files, so merges stay easy.

## 1. What to build

`C:\Users\Administrator\Downloads\CC_207B_Final_Project_Requirements.pdf` (pp. 1–2) requires **6 core features for 5 members**. Sign-in, registration, splash and navigation add zero to the count. Manual profile entry and its AI help count as **one** feature.

| Core feature | Founder input | What the app does | What the founder sees |
| --- | --- | --- | --- |
| F1 · AI-assisted startup profile | Fill in **What can you offer?** and **What do you need?**, tap **Suggest tags**, correct the chips, complete the details and save. | The bundled model picks tags for each box. The founder's final chips are saved. | Suggested chips under each box, then a finished startup card. Manual chips always work too. |
| F2 · Discover and save a match | Search by name, open **Why this match**, save a partner. | Compare offers and needs both ways and score the fit. Save the partner's ID on the founder's startup. | “They offer Beta Testers · You offer Product Feedback.” Campus Grocer stays in Saved after a refresh. |
| F3 · Send and decide an introduction | BudgetBuddy sends a note. Campus Grocer accepts or declines (in the demo, **Simulate Campus Grocer accepting**). BudgetBuddy can withdraw while pending. | Save the exchange as pending. Only the recipient can accept or decline. Accepting turns the exchange into a room. | **Pending — waiting for Campus Grocer**, then **Accepted** and **Open room**. |
| F4 · Agree on terms | BudgetBuddy fills in goal, tester count, testing window and deliverables. Campus Grocer agrees. | Whoever saves the terms agrees automatically. Editing the terms clears the other side's agreement. Both agreed = locked. | Both names with ✓ or “pending”, then **Terms agreed** and read-only fields. |
| F5 · Confirm milestones | Check **Testers assigned**, then **Feedback submitted** with a short note. The partner confirms each one. | A step is done only when both startups confirm it. Step 2 unlocks after step 1. Both steps done = **Launched**. | **Waiting on Campus Grocer**, then 0/2 → 1/2 → 2/2 and **Launched**. |
| F6 · Blind peer reviews | Each founder rates the partner 1–5 with an optional note. | Save one review per startup. Show the partner's review only after both have submitted. | “Campus Grocer has submitted a review. Submit yours to see it.” Then both reviews and **Reviewed**. |

**How the AI picks tags.** Because offers and needs come in separate boxes, the model only answers one question: *which of the 4 tags does this sentence talk about?* The app splits each box into short pieces (at periods, commas, “and”), asks the model about each piece, and collects the tags. Example: the offer box “We can review your app and give design feedback” → **Product Feedback**. The need box “We need students to try our signup” → **Beta Testers**. The four tags are **Beta Testers**, **Product Feedback**, **User Research** and **Technical Development**, plus a **none** label for filler sentences.

**Privacy.** The text never leaves the laptop: the model runs inside the browser. Say so next to **Suggest tags**. All data stays in this browser on this laptop, and clearing site data deletes it. Write this down for the brief's RA 10173 section.

### How the simulated partner works

You demo as BudgetBuddy the whole time. Campus Grocer is a sample startup, so no second login or tab is needed.

| You do this as BudgetBuddy | Then tap in Demo controls | The app shows |
| --- | --- | --- |
| Send Campus Grocer an introduction | — | **Pending — waiting for Campus Grocer** |
| — | **Simulate Campus Grocer accepting** | **Accepted**, and the room opens |
| Propose terms for three testers | — | BudgetBuddy ✓, Campus Grocer pending |
| — | **Simulate Campus Grocer agreeing** | **Terms agreed**, first milestone available |
| Check **Testers assigned** | **Simulate Campus Grocer confirming** | 1/2, step 2 unlocks |
| Write the note, check **Feedback submitted** | **Simulate Campus Grocer confirming** | 2/2 and **Launched** |
| — | **Simulate Campus Grocer reviewing** | A review exists but is hidden |
| Submit BudgetBuddy's review | — | Both reviews and **Reviewed** |

- **One button, one next step.** The label shows Campus Grocer's next allowed action. If there's nothing to do, the button is disabled and says why, for example “Campus Grocer is waiting for you to propose terms.”
- **Same functions, different actor.** The button calls the same store function a founder would, with Campus Grocer's ID, for example `store.acceptInvite(exchange, campusGrocerId)`. It never edits data directly.
- **Clearly labeled.** Put it in a collapsible card titled **Demo controls · simulated partner**, with a **Reset demo data** button for clean rehearsals.
- **Only the partner is simulated.** The AI still uses a real model.

## 2. How the code is organized

### Files

About 16 Dart files, each with one main owner.

| File | What it does | Owner |
| --- | --- | --- |
| `lib/main.dart` | Starts the app, loads the store, shows sign-in or the `NavigationBar` shell (Matches · Exchanges · My startup) | 2 |
| `lib/models.dart` | `Startup` and `Exchange` classes with `toJson` / `fromJson` | 3 |
| `lib/app_store.dart` | The data, the save slot, the signed-in founder, sample startups, and every action (`sendInvite`, `acceptInvite`, `agreeTerms` …) | 3 (others add their actions) |
| `lib/rules.dart` | Pure Dart rules and the match score. No Flutter imports, easy to unit-test | each author adds their own rules |
| `lib/tag_ai.dart` | Splits the boxes into pieces and asks the model for tags | 1 |
| `lib/screens/sign_in_screen.dart` | Sign in and register | 1 |
| `lib/screens/profile_screen.dart` | My startup form with the two boxes | 1 |
| `lib/screens/matches_screen.dart` | Suggested · Saved · Browse all, search, match cards | 2 |
| `lib/screens/match_detail_screen.dart` | **Why this match**, save, send introduction | 2 |
| `lib/screens/exchanges_screen.dart` | Needs your reply · Sent · Rooms | 3 |
| `lib/screens/room_screen.dart` | Room header with both names, holds the three panels below | 4 |
| `lib/widgets/tag_editor.dart` | Offer/need chips, suggested chips, manual add | 1 |
| `lib/widgets/terms_panel.dart` | Terms form and agreement status | 4 |
| `lib/widgets/milestone_panel.dart` | Two steps, checks, note, progress | 5 |
| `lib/widgets/review_panel.dart` | Rating, note, hidden/released views | 3 |
| `lib/widgets/demo_controls.dart` | Simulate button and **Reset demo data** | 5 |
| `web/tag_classifier.js`, `web/tag_model/`, `web/mediapipe/`, `ml/` | JS bridge to the model, the trained model, MediaPipe files, training CSV and notebook | 1 |
| `test/rules_test.dart`, `test/widget_test.dart` | Rule and score tests, one screen test | everyone |

### The data: two lists

**`Startup`** · `id`, `email`, `password`, `name`, `description`, `industry`, `stage`, `teamSize`, `offerText`, `needText`, `offers` (tags), `needs` (tags), `savedIds` (bookmarked startup IDs).

**`Exchange`** · everything about one partnership:

| Part | Fields |
| --- | --- |
| Invitation | `id`, `senderId`, `recipientId`, `note`, `stage` (`pending`, `declined`, `withdrawn`, `accepted`, `termsAgreed`, `launched`, `reviewed`) |
| Terms | `goal`, `testerCount`, `testingWindow`, `deliverables`, `termsAgreedBy` (list of startup IDs) |
| Milestones | `step1ConfirmedBy`, `step2ConfirmedBy` (lists of startup IDs), `feedbackNote` |
| Reviews | `ratings` (startup ID → 1–5), `reviewNotes` (startup ID → text) |

Using lists of IDs keeps the rules short. For example, a step is done when `step1ConfirmedBy` contains both startups' IDs.

### Saving: one save slot

Use the `shared_preferences` package. The whole app's data is saved as one JSON string, like a single save slot in a game. On first run (or after **Reset demo data**) the store fills `startups` with BudgetBuddy, Campus Grocer and one unrelated sample startup.

```dart
class AppStore extends ChangeNotifier {
  List<Startup> startups = [];
  List<Exchange> exchanges = [];

  // Open the save slot when the app starts
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('synergy');
    if (text == null) {
      startups = sampleStartups(); // first run: add the samples
      return;
    }
    final data = jsonDecode(text);
    startups = [for (final s in data['startups']) Startup.fromJson(s)];
    exchanges = [for (final e in data['exchanges']) Exchange.fromJson(e)];
  }

  // Change something, save it, and refresh the screens
  Future<void> update(void Function() change) async {
    change();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('synergy', jsonEncode({
      'startups': [for (final s in startups) s.toJson()],
      'exchanges': [for (final e in exchanges) e.toJson()],
    }));
    notifyListeners();
  }

  // Start fresh for a new demo run
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('synergy');
    startups = sampleStartups();
    exchanges = [];
    notifyListeners();
  }
}
```

Every action checks a rule, then calls `update()`:

```dart
// Partner accepts the invitation
void acceptInvite(Exchange e, String actorId) {
  if (!Rules.canAccept(e, actorId)) return; // not allowed, do nothing
  update(() => e.stage = 'accepted');
}
```

Team habits that prevent most bugs:

- Every change goes through `update()`, or it won't be saved.
- When you add a field to `Startup` or `Exchange`, add it to `toJson` **and** `fromJson`.
- If the app crashes after a model change, tap **Reset demo data** (old saved data no longer fits).
- The save slot belongs to the address, **including the port**. Always run on `localhost:8080`, or the app starts empty.

### Rules in `rules.dart`

Small functions that return `true`/`false` or a number. Each one gets a unit test.

| Rule | Meaning |
| --- | --- |
| `canSendInvite(from, to, exchanges)` | Not to yourself, and no open exchange with that startup already |
| `canAccept` / `canDecline(e, actorId)` | Only the recipient, only while pending |
| `canWithdraw(e, actorId)` | Only the sender, only while pending |
| `termsLocked(e)` | Both startups are in `termsAgreedBy` |
| `canConfirmStep(e, step, actorId)` | Terms locked, step 2 only after step 1 is done, a note is required for step 2 |
| `canSeeReview(e, viewerId, authorId)` | Your own review always. The partner's only after both have submitted |
| `matchFit(a, b)` | 0–100 tag fit (see M2) |
| `nextPartnerAction(e, partnerId)` | The label and action for the Demo controls button |

### Screens update themselves

`AppStore` extends `ChangeNotifier` (built into Flutter). `main.dart` loads it once with a `FutureBuilder` and a loading spinner, then passes it down. Each screen wraps its content in `ListenableBuilder(listenable: store, …)`. When `update()` calls `notifyListeners()`, every screen redraws, so there are no Refresh buttons. Use `setState` only for things inside one screen, like text fields or which tab is open.

Navigation: one `NavigationBar` with **Matches**, **Exchanges** and **My startup**. Open match detail and the room with `Navigator.push`. Use `Row`, `Column` and `Wrap` for layout, and let chips wrap on narrow screens.

### Sign-in

Registration creates a `Startup` with an email and password. Sign-in finds the matching startup. This is **demo-only sign-in**: tell testers to use dummy passwords, and list it as a limitation. Save the signed-in startup's ID in the tab's **session storage** (`package:web`, `window.sessionStorage`) so two developer tabs can act as different startups.

**Two-tab rule.** Each tab reads the save slot when the page loads. Before acting in a tab, **reload that page** (F5) so it has the latest data. Otherwise it could save over the other tab's change. This only matters for the developer check. The demo uses one tab.

### The AI (MediaPipe, Option B)

**Train (once, in Colab).** Write `ml/tag_examples.csv` with two columns, `text` and `label`. Aim for 20–40 short sentences per label (the 4 tags plus `none`), with roughly the same number for each. Keep about 10 sentences aside for testing. Train with MediaPipe Model Maker's text classifier and export a `.tflite` file to `web/tag_model/`. [Model Maker text classifier](https://ai.google.dev/edge/mediapipe/solutions/customization/text_classifier)

**Bundle (works offline).** Copy the `@mediapipe/tasks-text` package files, including its `wasm` folder, into `web/mediapipe/`. Then load them from there instead of a CDN. MediaPipe's `FilesetResolver.forTextTasks` accepts a base path for the WASM files, and `TextClassifier.createFromModelPath` loads a model from a path. [MediaPipe Text Classifier for Web](https://ai.google.dev/edge/mediapipe/solutions/text/text_classifier/web_js)

**Bridge from JavaScript to Dart.** One small JS file, loaded in `web/index.html` with `<script type="module" src="tag_classifier.js"></script>`:

```js
// web/tag_classifier.js
import { FilesetResolver, TextClassifier } from './mediapipe/text_bundle.mjs'; // check the exact file name in the folder

let classifier;

// Load the model once
async function loadModel() {
  const files = await FilesetResolver.forTextTasks('./mediapipe/wasm');
  classifier = await TextClassifier.createFromModelPath(files, './tag_model/tag_model.tflite');
}

// Give back the best tag for one short piece of text
window.classifyTag = async (text) => {
  if (!classifier) await loadModel();
  const best = classifier.classify(text).classifications[0].categories[0];
  return best.score >= 0.6 ? best.categoryName : 'none';
};
```

```dart
// lib/tag_ai.dart
import 'dart:js_interop';

@JS('classifyTag')
external JSPromise<JSString> _classifyTag(JSString text);

// Ask the model about one piece of text
Future<String> classifyTag(String text) async =>
    (await _classifyTag(text.toJS).toDart).toDart;

// Split a box into pieces and collect the tags
Future<List<String>> suggestTags(String boxText) async {
  final pieces = boxText.split(RegExp(r'[.,;]| and '));
  final tags = <String>{};
  for (final p in pieces) {
    if (p.trim().length < 4) continue; // skip tiny bits
    final tag = await classifyTag(p.trim());
    if (tag != 'none') tags.add(tag);
  }
  return tags.toList();
}
```

**In the screen.** While suggestions load, disable **Suggest tags** and show **Reading your description…**. Wrap the call in `.timeout(const Duration(seconds: 10))`. If it fails, times out or finds nothing, show “No tags found. Choose them manually.” The manual chips are always available.

## 3. Build in milestones

### Pick one part per person

Replace Member 1–5 with your names. Each person owns a feature, its files, its tests and its Demo controls step.

| Member | Own and defend | First contribution | Checked by |
| --- | --- | --- | --- |
| **1 · Profile and AI** | F1 · Profile form, two boxes, AI suggestions, manual fallback | Sign-in screen. Run the AI spike on the demo laptop | 2 checks that a corrected tag changes the match |
| **2 · Discovery** | F2 · Match score, search, Saved | `main.dart` shell and a plain startup list | 1 changes a profile and checks the score |
| **3 · Data, introductions and reviews** | F3 and F6 · Invites, blind reviews, `models.dart`, `app_store.dart` | **Save an invitation locally:** the save slot and `sendInvite` | 4 checks pending → room. 5 checks review privacy |
| **4 · Room and terms** | F4 · Terms form and agreement | Room screen showing both startup names | 5 checks that editing clears the partner's agreement |
| **5 · Milestones and Demo controls** | F5 · Two-step confirmations and progress, the Demo controls card | Exchanges inbox buttons, Demo controls, **Reset demo data** | 4 checks that one check can't complete a step |

### Four-week Gantt chart

**A** = first two working days of the week, **B** = the next three. **■** = build alone. **◆** = short team or pair check.

| Work and owners | W1 A | W1 B | W2 A | W2 B | W3 A | W3 B | W4 A | W4 B |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| M0 · Shell, save slot, sample startups, sign-in · all five | ■◆ | | | | | | | |
| M1 · Invite saved, accepted, room opens · all five | | ■◆ | | | | | | |
| AI spike · model running on the demo laptop · 1 | | ■ | ◆ | | | | | |
| M2 · Profile form with two boxes · 1 | | | ■ | ■◆ | | | | |
| M2 · Match score and Saved · 2 | | | ■ | ■◆ | | | | |
| M3 · Terms · 4 | | | ■ | ■◆ | | | | |
| M4 · Milestones · 5 | | | ■ | ■ | ■◆ | | | |
| M5 · Blind reviews · 3 | | | | ■ | ■ | ■◆ | | |
| M6 · AI suggestions in the form · 1 | | | | | ■ | ■◆ | | |
| Demo controls · each author adds their step, 5 checks all labels | | ■ | | ■ | ■ | ◆ | | |
| M7 · Clean setup, full run, fixes · all five | | | | | | | ■◆ | |
| M7 · Rehearse, record, practice changes · all five | | | | | | | | ■◆ |

**Handoffs**

1. **End of Week 1 · first checkpoint.** Open **two tabs**. Tab A signs in as BudgetBuddy, Tab B as Campus Grocer. BudgetBuddy sends an invite. Reload Tab B, accept. Reload Tab A: the room is there. Reload both again: same founders, same room. Then **Reset demo data** and do it again in one tab with **Simulate Campus Grocer accepting**. This proves the two startups act separately and the data survives a refresh.
2. **Start of Week 2 · AI decision.** Member 1 shows the spike result on the demo laptop. If the model is too weak, add more training sentences. If it won't run at all, decide now, not in Week 3. Manual tags stay available either way.
3. **End of Week 2.** Member 1 gives Member 2 a saved startup with tags. Member 4 gives Member 5 a room with agreed terms.
4. **Week 3.** Member 5 gives Member 3 a **Launched** room for reviews.

**Shared files.** `models.dart` and `app_store.dart` belong to Member 3. Others add their fields and actions in small PRs that Member 3 reviews. Each author adds their own rules and tests to `rules.dart` and `rules_test.dart`. Every PR gets one teammate's review.

### M0 · Shell, save slot and sign-in

**Files.** `pubspec.yaml`, `lib/main.dart`, `lib/models.dart`, `lib/app_store.dart`, `lib/screens/sign_in_screen.dart`, `README.md`.

1. **2 · Bootstrap.** In a new folder, run `flutter create --platforms=web synergy_flutter`. Add the logo, theme colors and a `NavigationBar` with three empty pages. Commit so others can branch.
2. **3 · Save slot.** `flutter pub add shared_preferences`. Write `Startup` with `toJson`/`fromJson`, `AppStore` with `load`, `update`, `reset` and `sampleStartups()`.
3. **1 · Sign-in.** `flutter pub add web`. Build sign-in and register forms with validation. Keep the signed-in ID in session storage. Show the shell after sign-in.
4. **4 and 5 · Setup checks.** Member 4 runs it on a second laptop and writes the README command: `flutter run -d web-server --web-port=8080`, then open `http://localhost:8080` in the normal browser. Member 5 adds a widget test for the sign-in screen and the first **Reset demo data** button. In tests, call `SharedPreferences.setMockInitialValues({})` first.

**Pass when** you can sign in as BudgetBuddy, reload and still be BudgetBuddy. A second tab can be Campus Grocer at the same time. A wrong password shows a message. **Reset demo data** brings back the samples.

### M1 · Invitation round trip (F3)

**Files.** `lib/screens/matches_screen.dart` (plain list for now), `match_detail_screen.dart`, `exchanges_screen.dart`, `room_screen.dart`, `lib/widgets/demo_controls.dart`, `lib/rules.dart`, `lib/models.dart`, `lib/app_store.dart`.

1. **3 · Save an invitation locally.** Add `Exchange` (invitation fields first) and `sendInvite`. Then `acceptInvite`, `declineInvite` and `withdrawInvite`, each checking its rule. Unit-test `canSendInvite`, `canAccept` and `canWithdraw`.
2. **2 · Pick a partner.** A plain list of other startups → match detail → a note box (max 280 characters) → **Send introduction**.
3. **5 · Inbox and partner step.** In `exchanges_screen.dart`, show **Needs your reply** (Accept/Decline) and **Sent** (Withdraw). Add **Simulate Campus Grocer accepting** to Demo controls.
4. **4 · Rooms.** Show accepted exchanges under **Rooms**. Tapping one opens `room_screen.dart` with both startup names.
5. **1 and 5 · Run the first checkpoint** (handoff 1). Member 3 also tries decline, withdraw and sending twice.

**Pass when** Campus Grocer reads “Could your students test our signup?” in Needs your reply. BudgetBuddy has no room until Campus Grocer accepts, then both see the same room after reloading. A second invite to the same startup is blocked. In one tab, the simulate button works and is disabled (with a reason) before anything is sent.

### M2 · Profiles and matches (manual F1, all of F2)

**Files.** `lib/screens/profile_screen.dart`, `lib/widgets/tag_editor.dart`, `lib/screens/matches_screen.dart`, `match_detail_screen.dart`, `lib/rules.dart`.

1. **1 and 2 · Agree on the four tags** and write one pair of sample profiles with the expected score.
2. **1 · Profile form.** Required: name, industry, stage, team size above 0, the two boxes, and at least one offer tag and one need tag (chosen manually for now). Use `Form` and `TextFormField` validators. Save with `store.update()`.
3. **2 · Match score.** In `rules.dart`: the share of A's needs that B offers, and the share of B's needs that A offers. Fit = 100 × the smaller share, rounded. No needs = 0. Unit-test it with the sample pair.
4. **2 · Matches screen.** Tabs **Suggested** (fit above 0, highest first), **Saved** and **Browse all**, plus search by name. Show both directions on the card and in **Why this match**. Saving adds the ID to `savedIds`. Show **Clear search** for no results and **Browse matches** for an empty Saved tab.
5. **1 and 2 · Test together.** In a second tab, sign in as Campus Grocer and change its needs. Reload BudgetBuddy's tab and check the score.

**Pass when** the sample pair scores 100%. Adding **User Research** to Campus Grocer's needs drops it to 50% with the reason shown. Removing it brings back 100%. A blank name or team size 0 is blocked. Saved survives a reload.

### M3 · Terms (F4)

**Files.** `lib/widgets/terms_panel.dart`, `lib/rules.dart`, `lib/models.dart`, `lib/app_store.dart`, `lib/widgets/demo_controls.dart`.

1. **4 · Fields and actions.** Add the term fields and `termsAgreedBy` to `Exchange`. `saveTerms(e, actorId, …)` sets the fields and makes `termsAgreedBy = [actorId]`, which also clears the partner's agreement. `agreeTerms(e, actorId)` adds the actor. When both are in, set the stage to `termsAgreed`.
2. **4 · Form.** Validate: goal and deliverables not empty, tester count above 0. Show each startup's name with ✓ or “pending”. Make the fields read-only once locked.
3. **4 · Partner step.** Add **Simulate Campus Grocer agreeing**.

**Pass when** BudgetBuddy saves 3 testers and sees itself ✓ and Campus Grocer pending. After the simulated agreement, both show ✓, **Terms agreed** and read-only fields, even after a reload. In a separate test, Campus Grocer agrees, then BudgetBuddy edits the count before it's locked: Campus Grocer's ✓ disappears.

### M4 · Milestones (F5)

**Files.** `lib/widgets/milestone_panel.dart`, `lib/rules.dart`, `lib/models.dart`, `lib/app_store.dart`, `lib/widgets/demo_controls.dart`.

1. **5 · Fields and action.** Add `step1ConfirmedBy`, `step2ConfirmedBy` and `feedbackNote`. `confirmStep(e, step, actorId, {note})` checks `canConfirmStep`, adds the actor and, if both steps are done, sets the stage to `launched`. The first person to confirm step 2 writes the note.
2. **5 · Panel.** Two rows with both startups' names and ✓, a note box for step 2, and the progress (0/2, 1/2, 2/2). After your own check, show **Waiting on Campus Grocer**.
3. **5 · Partner step.** Add **Simulate Campus Grocer confirming**, available only after BudgetBuddy has checked that step.

**Pass when** BudgetBuddy's check alone keeps 0/2 with **Waiting on Campus Grocer**. Tapping again changes nothing. The simulated confirmation makes 1/2. A blank note blocks step 2. Both confirmations make 2/2 and **Launched**, even after a reload.

### M5 · Blind reviews (F6)

**Files.** `lib/widgets/review_panel.dart`, `lib/rules.dart`, `lib/models.dart`, `lib/app_store.dart`, `lib/widgets/demo_controls.dart`.

1. **3 · Fields and action.** Add `ratings` and `reviewNotes`. `submitReview(e, actorId, rating, note)` saves once (a second submit changes nothing) and sets **Reviewed** when both have submitted.
2. **3 · Panel.** Show the form only when the room is launched. Every review shown goes through `canSeeReview`. Before release, show “Campus Grocer has submitted a review. Submit yours to see it.”
3. **3 · Partner step.** Add **Simulate Campus Grocer reviewing** (for example 5/5, “Clear onboarding, quick to recruit for.”). It's available as soon as the room is launched.

**Pass when** after the simulated review, BudgetBuddy sees that it exists but not its rating or note. After BudgetBuddy submits 4/5, both reviews show and the room reads **Reviewed**, even after a reload. The unrelated sample startup, signed in in another tab, doesn't see the room.

### M6 · AI suggestions (finish F1)

**Files.** `lib/tag_ai.dart`, `lib/widgets/tag_editor.dart`, `lib/screens/profile_screen.dart`, `web/tag_classifier.js`, `web/index.html`, `web/tag_model/`, `web/mediapipe/`, `ml/`.

**AI spike (Week 1).** Member 1 writes the training CSV, trains the model in Colab, and gets `classifyTag` running **on the demo laptop with Wi-Fi off**. Record the load time, the time per box, and the result for the two example boxes. Test the 10 held-out sentences and write down the score, for example “8/10 correct.”

1. **1 · Connect it.** Add a **Suggest tags** button under each box. Call `suggestTags(boxText)` and show the result as suggested chips.
2. **1 · Let the founder correct.** Suggested chips are separate until the founder taps **Apply**. They can remove a chip, add one manually, or ignore the suggestions. Only **Save** publishes.
3. **1 · Handle failure simply.** Disable the button while it runs, use the 10-second timeout, and show “No tags found. Choose them manually.” if anything goes wrong.
4. **1 and 2 · Check from the other side.** Remove one suggested chip, save, and check the card and score from Campus Grocer's tab.

**Pass when** with Wi-Fi off, the offer box suggests **Product Feedback** and the need box suggests **Beta Testers**. A removed chip doesn't appear on the saved card. Renaming `tag_model.tflite` (to force a failure) shows the manual message, and the profile can still be saved.

### M7 · Final checks and rehearsal

1. **Week 4A · Split the checks.** 1: AI success, correction and failure. 2: layouts at laptop and phone width, chip wrapping, Back keeps the search. 3: invites and reviews, with two tabs and with the simulate buttons. 4: a clean clone following the README. 5: every Demo controls label and **Reset demo data**.
2. **Week 4A · Full run.** On one commit, run `flutter analyze` and `flutter test`. Reset, then do M1–M6 in one tab. Fix and repeat anything that fails.
3. **Week 4B · Rehearse.** Member 1 drives BudgetBuddy and the Demo controls. 2 explains the score, 3 the invite rule and blind reviews, 4 the terms, 5 the milestones and the simulated partner. Each member practices their small change from section 4.

**Pass when** a teammate can run the full exchange in one tab from the README and show all six features without editing saved data by hand.

## 4. Submission and defense

### Topic Coverage Matrix

Fill in the real file and class from the final commit, and attach a screenshot or test result.

| Course topic | Planned file · widget/class | Evidence |
| --- | --- | --- |
| Value components | `matches_screen.dart` · match card | `Text`, `Icon` and `Chip` show name, offers and needs (M2) |
| Layout widgets | `main.dart`, `tag_editor.dart` · `TagEditor` | `Column`, `Row` and `Wrap` keep cards and chips readable on laptop and phone width (M2, M7) |
| Interaction components | `milestone_panel.dart` · `MilestonePanel`, `demo_controls.dart` · `DemoControls` | Check buttons and the simulate button whose label follows the next step (M1, M4) |
| Navigation and routing | `main.dart` · `NavigationBar`, `match_detail_screen.dart` | Switch pages, push match detail and the room, Back keeps the search (M1–M2) |
| Forms and validation | `profile_screen.dart` · `ProfileScreen`, `terms_panel.dart` · `TermsPanel` | Blank name and tester count 0 are blocked with inline messages (M2–M3) |
| Asynchronous operations | `main.dart` · `FutureBuilder`, `tag_ai.dart` | Loading spinner while the save slot loads, AI loading text, timeout and manual fallback (M0, M6) |
| Data persistence | `app_store.dart` · `AppStore` | The invite and room survive a reload (M1, M4) |
| AI-powered feature | `tag_ai.dart`, `web/tag_classifier.js`, `web/tag_model/` | Model suggestion, a correction, the saved profile, and the failure fallback (M6) |

### Submission checklist

- [ ] **Software documentation.** App name, problem, purpose, target users (a campus startup incubator is a realistic client). Flutter/Dart, `shared_preferences`, `web`, MediaPipe Text, and the versions actually used.
- [ ] **Functional requirements and UI.** F1–F6 inputs, results, rules and screenshots. Explain the **simulated partner** and the single exchange template. Limitations: one device only, demo-only sign-in, data readable with browser developer tools. Next improvement: a shared backend.
- [ ] **Screenshots.** AI tags before/after a correction, a match and Saved, pending and accepted invite, agreed terms, a milestone waiting and then confirmed, reviews hidden and released, a validation error, the AI fallback, and one two-tab checkpoint screenshot. Use dummy data and passwords.
- [ ] **AI feature specification.** Model type (MediaPipe Model Maker text classifier), training CSV size, labels, held-out score, sample inputs and outputs, why splitting into pieces helps, the threshold, correction controls, failure fallback, and that text stays on the device. Plus the AI Usage Log and each member's half-page reflection.
- [ ] **GitHub.** Fork the course repo, feature branches, regular commits, one review per PR. README with the fixed port, model files and training notebook. Final PR from the group fork.
- [ ] **Presentation and recording.** Short slides (problem, users, six features, screenshots, limits, next steps). Record one full successful run and keep a local copy.
- [ ] **Individual evidence.** Each member's commits, reviewed PRs and tests. Complete the self/peer assessment.

### Eight-minute live demo in one tab

Before the panel arrives: **Reset demo data**, sign in as BudgetBuddy, and turn Wi-Fi off once to confirm the AI still works.

| Time | What the panel sees |
| --- | --- |
| 0:00–0:40 | The problem and the two startups. Explain that Campus Grocer is a sample partner simulated through the same rules. |
| 0:40–1:40 | **F1.** Fill in both boxes, tap **Suggest tags**, remove or add a chip, save. |
| 1:40–2:35 | **F2.** Suggested, **Why this match** in both directions, save Campus Grocer, open Saved. |
| 2:35–3:35 | **F3.** Send “Can three students test our signup?”, show Pending, simulate accepting, open the room. |
| 3:35–4:40 | **F4.** Propose three testers, a one-week window and deliverables, simulate agreeing, show the locked terms. |
| 4:40–6:10 | **F5.** Check step 1 (waiting), simulate (1/2). Write the note, check step 2, simulate (2/2, **Launched**). |
| 6:10–7:15 | **F6.** Simulate Campus Grocer's review (hidden), submit BudgetBuddy's, show both and **Reviewed**. |
| 7:15–8:00 | Reload to show persistence. Name the limits (one device, simulated partner) and the next step (shared backend). |

### Individual code defense · 2–3 minutes each

| Feature · author | Decision to explain | Small live change to practice |
| --- | --- | --- |
| F1 · Member 1 | Why are suggestions separate from saved chips until Apply and Save? How does `suggestTags` split the box? | Show the number of selected suggestions on the Apply button |
| F2 · Member 2 | In `matchFit`, why does the weaker direction set the score? Show 100% → 50% | Show “1 of 2 needs covered” beside the percentage |
| F3 · Member 3 | How does `canAccept` stop BudgetBuddy from accepting its own invite, and how does the simulate button use the same rule? | Add a characters-remaining counter to the note (5 typed → 275 left) |
| F4 · Member 4 | Why does editing the terms clear the partner's agreement? | Show “Agreed by 1 of 2” under the terms |
| F5 · Member 5 | Why doesn't one startup's check complete a step? How does `nextPartnerAction` pick the button label? | Show “1 of 2 startups confirmed” on a half-done step |
| F6 · Member 3 (5 reviews) | Where does `canSeeReview` hide the partner's review, and what releases it? | Show the chosen number beside the star rating |

## 5. Design reference

- **Screens to match:** `synergy_lofi_prototype.html` *(not on this laptop yet)* (flow: Profile → Matches → Deal Room → Progress), `C:\Users\Administrator\Synergy\docs\product\Synergy.pdf` pp. 9–10 (AI profile, match list, terms, milestones, review), `synergy_prototype_screen_specs.md` *(not on this laptop yet)* screens 2–10, and `SynergyPrototype.pdf` *(not on this laptop yet)* pp. 3–6 and 8 (light match cards, Saved/Browse, rooms, profile). Swap any mentor content for startup names and exchange actions.
- **Colors:** teal `#00726F` for buttons, dark teal `#004543` for navigation, pale `#F2F4F1` behind white cards. **Logo:** `B/Synergy/assets/synergy-logo.png`, copied from `C:\Users\Administrator\Synergy\public\brand\synergy-logo.png` and listed under `assets:` in `pubspec.yaml`.
- **Layout:** put startup names side by side in the room, wrap chips, keep each action next to its status text, and use words and ✓ as well as color.
- **React version** (`C:\Users\Administrator\Synergy`) is a reference for screens and flow only. Don't copy its Node backend.

The course brief supplies the grading and submission requirements (pp. 1–6). The feature boundaries, technical choices, simulated partner and authorship are team planning decisions.
