// Every piece of text the user sees lives here, so wording is easy to find and
// change in one place. Add new text to the group it belongs to.

/// User-facing text for the whole app.
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'AgosUgnayan';
  static const String tagline =
      'Latest crop prices and local buyers in Iloilo Province.';

  // Common buttons
  static const String retry = 'Try again';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String discard = 'Discard';
  static const String keepEditing = 'Keep editing';
  static const String save = 'Save';
  static const String undo = 'Undo';

  // Common states
  static const String loading = 'Loading…';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError =
      'Could not connect. Check your internet and try again.';
  static const String timeoutError =
      'This is taking too long. Please try again.';
  static const String permissionError =
      'You are not allowed to do this. Try logging out and in again.';

  // Discard changes dialog
  static const String discardTitle = 'Discard changes?';
  static const String discardMessage =
      'You have changes that are not saved yet. If you leave now, they will be lost.';

  // Validation messages: say what is wrong and how to fix it.
  static const String fieldRequired = 'Please fill in this field.';
  static const String emailInvalid =
      'Enter a valid email, like name@example.com.';
  static const String passwordTooShort =
      'Use at least 6 characters for your password.';
  static const String passwordsDontMatch =
      'The passwords do not match. Type the same password twice.';
  static const String numberInvalid = 'Enter a number, like 50 or 12.5.';
  static const String numberMustBePositive = 'Enter a number bigger than 0.';
  static const String priceTooManyDecimals =
      'Use at most 2 numbers after the decimal point, like 45.50.';

  /// Error for a field that is longer than [max] characters.
  static String tooLong(int max) => 'Keep this under $max characters.';

  static const String nameTooShort = 'Enter your name, at least 2 letters.';
  static const String selectRequired = 'Please choose one.';
  static const String dateRequired = 'Please pick a date.';

  // Firebase setup check (shown when lib/firebase_options.dart is a placeholder)
  static const String firebaseNotSetUpTitle = 'Firebase is not set up yet';
  static const String firebaseNotSetUp =
      'Run `flutterfire configure` in this folder, then restart the app. '
      'The README explains each step.';

  // Logging out
  static const String logOut = 'Log out';
  static const String logOutTitle = 'Log out?';
  static const String logOutMessage =
      'You will need your email and password to log in again.';
  static const String loggedOut = 'You are logged out.';

  // AI label, shown on anything the AI filled in
  static const String aiGenerated = 'AI-generated';
}
