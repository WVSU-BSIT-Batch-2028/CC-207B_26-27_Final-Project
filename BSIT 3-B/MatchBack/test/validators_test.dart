import 'package:flutter_test/flutter_test.dart';
import 'package:matchback/utils/validators.dart';

// Checks the contact form rules. No Firebase is needed.
void main() {
  test('full name is required', () {
    expect(validateFullName(null), 'Full name is required.');
    expect(validateFullName('   '), 'Full name is required.');
    expect(validateFullName('Sam Cruz'), isNull);
  });

  test('email is optional but must look valid when given', () {
    expect(validateEmail(''), isNull);
    expect(validateEmail('sam@school.edu.ph'), isNull);
    expect(validateEmail('sam@'), 'Enter a valid email address.');
  });

  test('phone accepts Philippine formats with spaces or dashes', () {
    expect(validatePhone(''), isNull);
    expect(validatePhone('0917 123 4567'), isNull);
    expect(validatePhone('+63 917 123 4567'), isNull);
    expect(validatePhone('12345'), 'Enter a valid Philippine phone number.');
  });

  test('cleanPhone removes spaces and dashes', () {
    expect(cleanPhone('0917 123-4567'), '09171234567');
  });

  test('at least one contact method is required', () {
    expect(
      validateContactMethod('', ''),
      'Provide an email address or a phone number.',
    );
    expect(validateContactMethod('sam@school.edu.ph', ''), isNull);
    expect(validateContactMethod('', '09171234567'), isNull);
  });
}
