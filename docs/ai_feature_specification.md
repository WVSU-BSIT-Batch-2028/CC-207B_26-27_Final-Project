# AI Feature Specification: Health360 Assistant

(CC 207B documentation, section "AI Feature Specification". Fill in the parts marked **TODO** from your own testing.)

## AI service, model and package
- **Service:** Firebase AI Logic with the Gemini Developer API (free Spark plan).
- **Model:** `gemini-3.1-flash-lite`, a stable Gemini 3.x Flash-Lite model that does not need the paid plan with the Gemini Developer API (one constant, `GeminiAssistantService.modelName`). `gemini-2.5-flash` returned a 404 during testing because it had been retired.
- **Packages:** `firebase_ai`, `firebase_core` and `firebase_app_check`. Versions: **TODO** copy from `pubspec.lock`.
- **Where in the code:** `lib/services/gemini_assistant_service.dart`, `ai_prompt.dart`, `ai_assistant_service.dart`; UI in `lib/screens/ai/ai_assistant_screen.dart`.

## Inputs and prompts
- **Input:** the patient's free-text message (3 to 500 characters) plus up to the last 6 messages for context.
- **Privacy filter before sending:** emails, Philippine mobile numbers and long ID-like numbers are replaced with `[removed]` (`redactPersonalInfo`). No profile data (name, address, records) is sent.
- **System prompt:** defined in `assistantSystemPrompt`. It says the assistant is not a doctor, must not diagnose or prescribe, answers in at most 5 plain sentences, starts with `LEVEL: SELF_CARE | SEE_DOCTOR | URGENT`, sends emergencies to 911, helps with app questions, and refuses unrelated topics.

## Sample outputs
**TODO:** run the app with Firebase on and paste 3 real examples here (for example "headache and mild fever", "how do I refill my prescription", a message with a phone number). Include the care level shown on screen.

## How failures are handled, and the fallback
| Situation | What happens |
|---|---|
| Waiting for the answer | Typing indicator is shown |
| Takes longer than 12 seconds | Timeout, then offline guidance |
| No internet, quota used up, blocked content, any Firebase error | `AiServiceException`, then offline guidance |
| Empty or unreadable reply | Treated as a failure, then offline guidance. A missing care level becomes "See a doctor soon" |
| Firebase or App Check not set up on this device (including a missing App Check debug token) | Offline guidance, honestly labelled "not AI" |
| Emergency or self-harm words in the message | Fixed safety message shown first, labelled "Safety guidance", the model is not asked |

**Fallback:** rule-based guidance (`RuleBasedAssistant`) labelled "Offline guidance · not AI". The user can always book a consultation.

## Known failure cases
- The model can still be wrong or too general. It is labelled AI-generated and says it is not a diagnosis.
- Words the keyword safety check does not know (misspellings, other languages) are left to the model's own URGENT rule.
- Replies are English only.
- Free-tier limits can be reached during a busy demo; the fallback then takes over.
- **TODO:** add any odd results you saw while testing.

## Why AI is the right tool
People describe symptoms in free, messy, mixed wording ("masakit ulo", "feeling hot and dizzy since last night"). Keyword rules only match words we planned for, so they miss most real sentences. A language model can read the whole message, ask for context from earlier messages and answer in plain language. The rules are still used where they are better: emergencies and the offline fallback.

## Responsible use and privacy
- Every AI reply is labelled **AI-generated**. Fallback and safety messages are labelled **not AI**.
- The user can edit and resend a message, tap "This isn't right", or book a doctor at any time. Nothing is decided for them.
- Only the message text is sent, with personal details removed (data minimisation, Data Privacy Act of 2012, RA 10173). A banner asks users not to share names or ID numbers.
- Free-tier Gemini requests may be used by Google to improve its products, so this app uses sample data only.
- No API key is in the repository. Firebase settings are in `firebase_config.json`, which is ignored by Git.
- **Firebase App Check** is enforced for Firebase AI Logic, so only our app can call the AI (debug provider during development).

## AI Usage Log row to add (fill the last column yourself)
| Member | Date | AI tool | What it was used for / prompt summary | What was generated | What the member changed |
|---|---|---|---|---|---|
| Ysai | 2026-11-16 | Claude | Firebase setup and Gemini assistant: asked for the Firebase bootstrap, `GeminiAssistantService`, prompt/parser/redaction helpers, tests and this specification | firebase_config.dart, firebase_bootstrap.dart, gemini_assistant_service.dart, ai_prompt.dart, ai_exceptions.dart, edits to the AI service and screen, tests | _(write what you edited, fixed or re-implemented)_ |
