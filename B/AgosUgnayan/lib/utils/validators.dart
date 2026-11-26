// Reusable form validators. Each one returns null when the value is OK, or a
// friendly error message when it isn't. Use them as `validator:` on a
// TextFormField. They are unit-tested in test/validators_test.dart.

import 'strings.dart';

/// Validation helpers shared by every form in the app.
class Validators {
  Validators._();

  /// The field must not be empty (spaces only counts as empty).
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }

  /// A person's name: at least 2 letters, at most 60 characters.
  static String? name(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    if (value!.trim().length < 2) return AppStrings.nameTooShort;
    if (value.trim().length > 60) return AppStrings.tooLong(60);
    return null;
  }

  /// A simple email check: something@something.something
  static String? email(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(value!.trim())) return AppStrings.emailInvalid;
    return null;
  }

  /// Firebase Auth needs passwords of at least 6 characters.
  static String? password(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    if (value!.length < 6) return AppStrings.passwordTooShort;
    return null;
  }

  /// Builds a validator that checks the value equals [original], e.g. for a
  /// "Confirm password" field: `validator: Validators.matches(_passCtrl.text)`.
  static String? Function(String?) matches(String original) {
    return (value) {
      final empty = required(value);
      if (empty != null) return empty;
      if (value != original) return AppStrings.passwordsDontMatch;
      return null;
    };
  }

  /// A number bigger than 0, e.g. a quantity like "50" or "2.5".
  static String? positiveNumber(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    final number = double.tryParse(value!.trim());
    if (number == null) return AppStrings.numberInvalid;
    if (number <= 0) return AppStrings.numberMustBePositive;
    return null;
  }

  /// A price in pesos: bigger than 0 with at most 2 decimal places.
  static String? price(String? value) {
    final number = positiveNumber(value);
    if (number != null) return number;
    final parts = value!.trim().split('.');
    if (parts.length == 2 && parts[1].length > 2) {
      return AppStrings.priceTooManyDecimals;
    }
    return null;
  }

  /// Builds a validator that allows empty text but limits the length, e.g.
  /// for an optional description: `validator: Validators.maxLength(200)`.
  static String? Function(String?) maxLength(int max) {
    return (value) {
      if (value != null && value.trim().length > max) {
        return AppStrings.tooLong(max);
      }
      return null;
    };
  }
}
