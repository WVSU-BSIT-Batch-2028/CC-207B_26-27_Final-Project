import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/utils/friendly_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps pharmacist license errors to plain language', () {
    const err = PostgrestException(
      message: 'A verified and unexpired pharmacist license is required',
    );
    final friendly = resolveFriendlyError(err);
    expect(friendly.title, 'A licensed pharmacist must do this');
    expect(friendly.body, contains('General branch staff'));
    expect(friendly.nextStep, isNotNull);
  });

  test('strips Postgrest wrapper from stringified errors', () {
    final friendly = resolveFriendlyError(
      Exception(
        'PostgrestException(message: Not enough stock for "Betadine", code: P0001)',
      ),
    );
    expect(friendly.title, 'Not enough stock');
    expect(friendly.body, contains('Betadine'));
  });
}