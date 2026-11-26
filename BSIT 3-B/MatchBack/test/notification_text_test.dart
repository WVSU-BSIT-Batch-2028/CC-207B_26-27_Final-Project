import 'package:flutter_test/flutter_test.dart';
import 'package:matchback/utils/notification_text.dart';

// Checks the notification wording. No Firebase is needed.
void main() {
  test('approval message names the student and the item', () {
    final message = buildNotificationMessage(
      event: 'approved',
      name: 'Sam',
      itemName: 'Phone',
    );

    expect(message, contains('Sam'));
    expect(message, contains('"Phone"'));
    expect(message, contains('approved'));
  });

  test('ready message includes the office instructions', () {
    final message = buildNotificationMessage(
      event: 'ready',
      name: 'Sam',
      itemName: 'Phone',
    );

    expect(message, contains('ready for collection'));
    expect(message, contains(officeInstructions));
  });

  test('student text reflects whether staff reached them', () {
    expect(
      studentNotificationText(
        event: 'ready',
        method: 'email',
        outcome: 'contacted',
      ),
      'Staff contacted you by email: your item is ready for collection.',
    );
    expect(
      studentNotificationText(
        event: 'ready',
        method: 'phone',
        outcome: 'failed',
      ),
      contains('could not reach you'),
    );
  });
}
