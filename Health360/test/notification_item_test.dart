import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/notification_item.dart';

void main() {
  NotificationItem item({NotificationTarget? target, String? targetId}) =>
      NotificationItem(
        id: 'refill_1',
        categoryKey: 'prescription',
        title: 'Refill requested',
        message: 'A patient asked to refill Paracetamol.',
        time: DateTime(2026, 11, 25),
        target: target,
        targetId: targetId,
      );

  test('keeps its target when marked as read', () {
    final read = item(
      target: NotificationTarget.prescriptionDetails,
      targetId: 'rx-1',
    ).copyWith(read: true);

    expect(read.read, isTrue);
    expect(read.target, NotificationTarget.prescriptionDetails);
    expect(read.targetId, 'rx-1');
  });

  test('has no target unless one is given', () {
    expect(item().target, isNull);
    expect(item().targetId, isNull);
  });
}