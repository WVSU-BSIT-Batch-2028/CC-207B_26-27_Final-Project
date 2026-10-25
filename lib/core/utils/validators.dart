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

  /// A number between [min] and [max]. [label] is used in the messages,
  /// e.g. "heart rate". Set [wholeNumber] to reject decimals.
  static String? number(
    String? value, {
    required String label,
    required double min,
    required double max,
    bool wholeNumber = false,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Please enter your $label.';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter numbers only.';
    if (wholeNumber && parsed != parsed.roundToDouble()) return 'Use a whole number.';
    if (parsed < min || parsed > max) {
      return 'Enter a $label between ${_plain(min)} and ${_plain(max)}.';
    }
    return null;
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
