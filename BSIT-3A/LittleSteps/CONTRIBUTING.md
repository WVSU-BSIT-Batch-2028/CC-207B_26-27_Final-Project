# Contributing

## Branches and pull requests

1. Pick an issue assigned to you and branch from an up-to-date `main`:
   - `feat/<short-name>` for features
   - `fix/<short-name>` for bug fixes
   - `docs/<short-name>` for documentation
2. Commit with your own GitHub account and a clear message, for example `feat(journal): add entry form validation`.
3. Run `dart format .`, `flutter analyze` and `flutter test`. All three must pass.
4. Open a pull request into `main` and link the issue (`Closes #12`).
5. At least one other teammate reviews and approves before merging.

Commit early and often. Grading looks at each member's commits and pull requests across the whole project, not only near the deadline.

## Code conventions

- Put code in the matching folder: `screens/`, `widgets/`, `models/`, `services/`, `theme/` or `routing/`.
- Give every public class and important method a short `///` comment that says what it does.
- Use the colors, spacing and radii in `lib/theme/app_tokens.dart`. Do not hard-code new colors.
- Buttons and other tap targets are at least 48 × 48 dp.
- Screens that load data show loading, empty and error states. Use the widgets in `lib/widgets/state_views.dart`.

## AI usage log

The course allows AI help for snippets, debugging and sample data, as long as it is recorded. If you used AI for anything in your pull request, add a row to [docs/ai-usage-log.md](docs/ai-usage-log.md) in the same pull request. You must be able to explain and change any code you submit during the code defense.

AI may not write whole screens or large parts of the app, the individual reflections, or the self and peer assessments.

## Secrets and data

- Never commit API keys, keystores (`*.jks`, `*.keystore`), `key.properties` or `.env` files.
- Use made-up data in tests, screenshots and demos. Never use a real child's details.
