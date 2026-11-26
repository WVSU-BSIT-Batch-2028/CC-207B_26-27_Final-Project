// Removes personal contact details from text before we send it to the AI.
// The AI only needs the crop details, not phone numbers or emails
// (Data Privacy Act of 2012, RA 10173). Tested in test/privacy_filter_test.dart.

/// Replaces phone numbers and email addresses with "[removed]".
String removeContactDetails(String text) {
  // Emails like name@example.com
  final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  // PH mobile numbers like 09171234567, 0917 123 4567 or +63 917 123 4567
  final phone = RegExp(r'(\+63|0)\s?9\d{2}[\s-]?\d{3}[\s-]?\d{4}');
  return text.replaceAll(email, '[removed]').replaceAll(phone, '[removed]');
}
