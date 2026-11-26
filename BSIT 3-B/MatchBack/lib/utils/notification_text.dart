/// Where and when to collect an item. Change this to your real office.
const officeInstructions =
    'Please come to the Lost and Found office during office hours to '
    'collect it.';

/// The message staff copy and send. [event] is 'approved' or 'ready'.
String buildNotificationMessage({
  required String event,
  required String name,
  required String itemName,
}) {
  switch (event) {
    case 'approved':
      return 'Hello $name, your claim for "$itemName" on MatchBack was '
          'approved. We will let you know when it is ready for collection.';
    case 'ready':
      return 'Hello $name, your item "$itemName" is ready for collection. '
          '$officeInstructions Thank you.';
    default:
      return '';
  }
}

String notificationMethodLabel(String method) {
  switch (method) {
    case 'email':
      return 'email';
    case 'phone':
      return 'phone call';
    case 'text':
      return 'text message';
    default:
      return method;
  }
}

/// The sentence a student sees on My Claims for one staff contact attempt.
String studentNotificationText({
  required String event,
  required String method,
  required String outcome,
}) {
  final how = notificationMethodLabel(method);

  if (outcome == 'failed') {
    return 'Staff tried to contact you by $how but could not reach you. '
        'Please check this page for updates.';
  }

  final what = event == 'ready'
      ? 'your item is ready for collection'
      : 'your claim was approved';
  return 'Staff contacted you by $how: $what.';
}
