import 'package:flutter_test/flutter_test.dart';
import 'package:synergy_flutter/tag_ai.dart';

void main() {
  test('splits at periods', () {
    expect(splitPieces('Review our app. Try our signup.'), [
      'Review our app',
      'Try our signup',
    ]);
  });

  test('splits at commas', () {
    expect(splitPieces('Test checkout, review the dashboard'), [
      'Test checkout',
      'review the dashboard',
    ]);
  });

  test('splits at " and "', () {
    expect(splitPieces('Use our sandbox and review our demo'), [
      'Use our sandbox',
      'review our demo',
    ]);
  });

  test('splits at a capital "And" and at line breaks', () {
    expect(splitPieces('Use our sandbox\nAnd review our demo'), [
      'Use our sandbox',
      'review our demo',
    ]);
  });

  test('does not split inside words like "android" or "brand"', () {
    expect(splitPieces('Test our android brand app'), [
      'Test our android brand app',
    ]);
  });

  test('drops pieces shorter than four characters after trimming', () {
    expect(splitPieces('  ok. , abc ; test,  use our app  '), [
      'test',
      'use our app',
    ]);
  });
}
