/// Removes spaces, dashes and brackets so "0917 123-4567" becomes
/// "09171234567" before it is checked or saved.
String cleanPhone(String value) {
  return value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
}

String? validateFullName(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Full name is required.';
  if (text.length < 2) return 'Enter your full name.';
  if (text.length > 80) return 'Use 80 characters or fewer.';
  return null;
}

/// Email is optional here, so an empty value is accepted.
String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (text.length > 120) return 'The email address is too long.';
  final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  return pattern.hasMatch(text) ? null : 'Enter a valid email address.';
}

/// Phone is optional here. Accepts 09171234567 or +639171234567.
String? validatePhone(String? value) {
  final text = cleanPhone(value ?? '');
  if (text.isEmpty) return null;
  final pattern = RegExp(r'^(\+63|0)\d{9,10}$');
  return pattern.hasMatch(text)
      ? null
      : 'Enter a valid Philippine phone number.';
}

/// Staff need at least one way to reach the student.
String? validateContactMethod(String email, String phone) {
  if (email.trim().isEmpty && cleanPhone(phone).isEmpty) {
    return 'Provide an email address or a phone number.';
  }
  return null;
}
