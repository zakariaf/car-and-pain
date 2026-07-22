import 'package:core/core.dart';
import 'package:notifications/notifications.dart';
import 'package:test/test.dart';

ScheduledNotification _n(int id, int day, {String body = 'b'}) =>
    ScheduledNotification(
      id: id,
      when: Instant.fromEpochMillis(day * Duration.millisecondsPerDay),
      titleCode: 't',
      bodyCode: body,
    );

void main() {
  const reconciler = Reconciler();

  test('rebuild from an empty OS queue arms the whole desired set', () async {
    final g = FakeNotificationGateway();
    final r = await reconciler.reconcile(
      desired: [_n(1, 10), _n(2, 20), _n(3, 30)],
      current: const [],
      gateway: g,
    );
    expect(r.armed, 3);
    expect(r.mutations, 3);
    expect(await g.pendingIds(), unorderedEquals([1, 2, 3]));
  });

  test('is idempotent — a second identical pass mutates nothing', () async {
    final g = FakeNotificationGateway();
    final desired = [_n(1, 10), _n(2, 20)];
    await reconciler.reconcile(desired: desired, current: const [], gateway: g);
    final again = await reconciler.reconcile(
      desired: desired,
      current: desired, // now the last-armed set
      gateway: g,
    );
    expect(again.mutations, 0);
    expect(again.unchanged, 2);
  });

  test('cancels exactly the stale entry and leaves the rest', () async {
    final g = FakeNotificationGateway();
    await reconciler.reconcile(
      desired: [_n(1, 10), _n(2, 20)],
      current: const [],
      gateway: g,
    );
    final r = await reconciler.reconcile(
      desired: [_n(1, 10)], // reminder 2 deleted
      current: [_n(1, 10), _n(2, 20)],
      gateway: g,
    );
    expect(r.cancelled, 1);
    expect(r.unchanged, 1);
    expect(await g.pendingIds(), [1]);
  });

  test('re-arms the same id when its fire time or body changes', () async {
    final g = FakeNotificationGateway();
    await reconciler.reconcile(
      desired: [_n(1, 10)],
      current: const [],
      gateway: g,
    );
    final r = await reconciler.reconcile(
      desired: [_n(1, 12, body: 'new')], // re-projected + new copy, same id
      current: [_n(1, 10)],
      gateway: g,
    );
    expect(r.rescheduled, 1);
    expect(r.armed, 0);
    expect(await g.pendingIds(), [1]); // still exactly one entry
  });

  test('reboot: OS queue empty but DB knows the set → re-arm everything',
      () async {
    final g = FakeNotificationGateway(); // pending is empty (post-reboot)
    final r = await reconciler.reconcile(
      desired: [_n(1, 10), _n(2, 20)],
      current: [_n(1, 10), _n(2, 20)], // last-armed, per the DB
      gateway: g,
    );
    expect(r.armed, 2); // re-armed because the OS lost them
    expect(await g.pendingIds(), unorderedEquals([1, 2]));
  });

  test('windows to the soonest maxPending (iOS 64 cap), defers the rest',
      () async {
    final g = FakeNotificationGateway();
    const capped = Reconciler(maxPending: 3);
    final desired = [
      for (var i = 0; i < 10; i++) _n(i, 100 - i)
    ]; // varied times
    final r = await capped.reconcile(
      desired: desired,
      current: const [],
      gateway: g,
    );
    expect(r.armed, 3);
    expect(r.deferred, 7);
    expect((await g.pendingIds()).length, 3);
    // The soonest three (smallest `when`) are the ones armed.
    expect(await g.pendingIds(), unorderedEquals([9, 8, 7]));
  });

  test('stableNotificationId is deterministic, positive, and per-key', () {
    expect(stableNotificationId('r1#0'), stableNotificationId('r1#0'));
    expect(stableNotificationId('r1#0'), isNot(stableNotificationId('r1#1')));
    expect(stableNotificationId('anything'), greaterThanOrEqualTo(0));
  });
}
