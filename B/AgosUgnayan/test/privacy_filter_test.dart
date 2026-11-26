// Unit tests for removeContactDetails: phone numbers and emails never reach
// the AI.

import 'package:agosugnayan/utils/privacy_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes a mobile number', () {
    expect(
      removeContactDetails('50 kg kamatis, text 09171234567'),
      '50 kg kamatis, text [removed]',
    );
  });

  test('removes a number with +63 and spaces', () {
    expect(removeContactDetails('call +63 917 123 4567'), 'call [removed]');
  });

  test('removes an email', () {
    expect(removeContactDetails('email pedro@gmail.com'), 'email [removed]');
  });

  test('keeps normal crop details', () {
    expect(
      removeContactDetails('50 kilos talong, 45 pesos'),
      '50 kilos talong, 45 pesos',
    );
  });
}
