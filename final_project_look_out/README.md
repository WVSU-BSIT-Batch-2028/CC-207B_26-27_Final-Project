# final_project_look_out

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Admin account management

Creating an account uses the `createUserAccount` callable function in
[the Firebase Functions package](../functions). Install its dependencies from
the repository root with `npm ci --prefix functions`, then deploy it with
`firebase deploy --only functions:createUserAccount`.

Deleting an account removes its Firestore `users` document only. Its Firebase
Authentication account may remain.
