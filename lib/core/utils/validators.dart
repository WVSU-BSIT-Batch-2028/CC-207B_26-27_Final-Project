/// Form validators shared by every form in the app.
/// Each returns an error message, or null when the value is valid.
class Validators {
  Validators._();

  static String? fullName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Please enter your full name.';
    if (text.length < 2) return 'That name looks too short.';
    if (!RegExp(r"^[A-Za-zÀ-ÿ.'\- ]+$").hasMatch(text)) {
      return 'Use letters only (no numbers or symbols).';
    }
    return null;
  }

  /// Philippine mobile number: 09XXXXXXXXX or +639XXXXXXXXX.
  static String? mobile(String? value, {bool isRequired = false}) {
    final text = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (text.isEmpty) return isRequired ? 'Please enter your mobile number.' : null;
    if (!RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(text)) {
      return 'Enter a valid PH number, e.g. 09123456789.';
    }
    return null;
  }

  static String? address(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null; // optional
    if (text.length < 5) return 'Please enter a more complete address.';
    return null;
  }
}
