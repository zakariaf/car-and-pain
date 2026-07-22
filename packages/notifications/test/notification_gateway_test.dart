import 'package:core/core.dart';
import 'package:notifications/notifications.dart';
import 'package:test/test.dart';

void main() {
  test('FakeNotificationGateway records and reconciles pending ids', () async {
    final gateway = FakeNotificationGateway();
    const n = ScheduledNotification(
      id: 1,
      when: Instant.fromEpochMillis(1_784_000_000_000),
      title: 'reminder.service_due.title',
      body: 'reminder.service_due.body',
    );

    expect((await gateway.schedule(n)).isOk, isTrue);
    expect(await gateway.pendingIds(), [1]);

    expect((await gateway.cancel(1)).isOk, isTrue);
    expect(await gateway.pendingIds(), isEmpty);
  });
}
