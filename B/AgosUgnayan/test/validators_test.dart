// Unit tests for lib/utils/validators.dart: each validator returns null for
// good input and the right friendly message for bad input.

import 'package:agosugnayan/utils/strings.dart';
import 'package:agosugnayan/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('required', () {
    test('rejects null, empty and spaces only', () {
      expect(Validators.required(null), AppStrings.fieldRequired);
      expect(Validators.required(''), AppStrings.fieldRequired);
      expect(Validators.required('   '), AppStrings.fieldRequired);
    });
    test('accepts text', () => expect(Validators.required('Talong'), isNull));
  });

  group('name', () {
    test('accepts a normal name', () {
      expect(Validators.name('Pedro Santos'), isNull);
    });
    test('rejects one letter', () {
      expect(Validators.name('P'), AppStrings.nameTooShort);
    });
  });

  group('email', () {
    test('accepts a normal email', () {
      expect(Validators.email('pedro@example.com'), isNull);
    });
    test('rejects text without @ or dot', () {
      expect(Validators.email('pedro'), AppStrings.emailInvalid);
      expect(Validators.email('pedro@example'), AppStrings.emailInvalid);
    });
    test('rejects empty', () {
      expect(Validators.email(''), AppStrings.fieldRequired);
    });
  });

  group('password', () {
    test('needs at least 6 characters', () {
      expect(Validators.password('12345'), AppStrings.passwordTooShort);
      expect(Validators.password('123456'), isNull);
    });
  });

  group('matches', () {
    test('compares with the original password', () {
      final validator = Validators.matches('secret1');
      expect(validator('secret1'), isNull);
      expect(validator('secret2'), AppStrings.passwordsDontMatch);
    });
  });

  group('positiveNumber', () {
    test('accepts numbers above 0', () {
      expect(Validators.positiveNumber('50'), isNull);
      expect(Validators.positiveNumber('2.5'), isNull);
    });
    test('rejects text, zero and negatives', () {
      expect(Validators.positiveNumber('fifty'), AppStrings.numberInvalid);
      expect(Validators.positiveNumber('0'), AppStrings.numberMustBePositive);
      expect(Validators.positiveNumber('-3'), AppStrings.numberMustBePositive);
    });
  });

  group('price', () {
    test('accepts up to 2 decimals', () {
      expect(Validators.price('45'), isNull);
      expect(Validators.price('45.50'), isNull);
    });
    test('rejects 3 decimals', () {
      expect(Validators.price('45.505'), AppStrings.priceTooManyDecimals);
    });
  });

  group('maxLength', () {
    final validator = Validators.maxLength(5);
    test('allows empty and short text', () {
      expect(validator(''), isNull);
      expect(validator('abc'), isNull);
    });
    test('rejects long text', () {
      expect(validator('abcdef'), AppStrings.tooLong(5));
    });
  });
}
