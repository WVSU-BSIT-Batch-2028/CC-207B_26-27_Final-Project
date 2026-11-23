# Topic Coverage – Authentication Module

| File | Class | Description |
|---|---|---|
| `lib/services/auth_service.dart` | `AuthService` / `AuthException` | Handles Firebase Email/Password authentication (`signIn`, `register`, `changePassword`, `sendPasswordReset`, `signOut`), persists and caches user profiles and roles (`patient` or `doctor`) in Cloud Firestore under `users/{uid}`, and throws typed `AuthException` errors. |
| `lib/screens/auth/auth_gate.dart` | `AuthGate` | Listens to Firebase authentication state changes via `StreamBuilder`, caches the signed-in user's Firestore role lookup per UID to prevent duplicate reads, and renders explicit loading and error/retry/sign-out states before routing to `LoginScreen`, `PatientShell`, or `DoctorShell`. |
| `lib/screens/auth/login_screen.dart` | `LoginScreen` | Provides the Email/Password sign-in form styled with `AppTheme.inputDecoration`, regex email validation (`Validators.email`), password visibility toggle, loading states, error banner display, password reset dialog, and navigation to `RegisterScreen`. |
| `lib/screens/auth/register_screen.dart` | `RegisterScreen` | Provides the account registration form styled with `AppTheme.inputDecoration`, strong password and email validation (`Validators`), Patient/Doctor role selection, and mandatory Data Privacy Act of 2012 (RA 10173) consent verification. |
| `lib/screens/profile/personal_info_screen.dart` | `PersonalInfoScreen` | Displays and updates the signed-in user's personal profile and provides a working Change Password dialog backed by `AuthService.changePassword`. |
| `lib/screens/profile/profile_screen.dart` | `ProfileScreen` | Displays the signed-in user's real name and email from Firestore/Auth and removes the obsolete demo view-switcher tile. |
| `lib/services/profile_service.dart` | `ProfileService` | Loads and saves user profile data from Firebase Auth and Cloud Firestore `users/{uid}` alongside local device preferences. |
| `lib/screens/patient/home/home_screen.dart` | `HomeScreen` | Displays the signed-in patient's first name in the dashboard greeting header instead of static sample data. |
| `lib/screens/doctor/doctor_home_screen.dart` | `DoctorHomeScreen` | Displays the signed-in doctor's last name in the dashboard greeting header instead of static sample data. |
| `lib/core/utils/validators.dart` | `Validators` | Provides shared regex email validation and strong password validation (minimum 8 characters with uppercase, lowercase, and numeric characters). |

## Known Limitations
- **Unrestricted Doctor Role Selection (Demo Scope):** During registration, any user can select the **Doctor** role without PRC license verification or administrator approval. In a production deployment, doctor accounts would require credential verification or admin role assignment via Firebase Custom Claims / Cloud Functions.