import 'package:car_and_pain/src/notifications/notification_channels.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// M5-T4 — each severity maps to the right per-channel delivery treatment so an
/// overdue item breaks through Focus while info/digests stay quiet.
void main() {
  test('severity → iOS interruption level', () {
    expect(iosInterruptionFor('overdue'), InterruptionLevel.timeSensitive);
    expect(iosInterruptionFor('dueSoon'), InterruptionLevel.active);
    expect(iosInterruptionFor('documents'), InterruptionLevel.active);
    expect(iosInterruptionFor('info'), InterruptionLevel.passive);
    expect(iosInterruptionFor('unknown'), InterruptionLevel.passive);
  });

  test('severity → Android priority', () {
    expect(androidPriorityFor('overdue'), Priority.max);
    expect(androidPriorityFor('dueSoon'), Priority.high);
    expect(androidPriorityFor('info'), Priority.low);
  });

  test('channels cover the four severities with matching importance', () {
    expect(channelFor('overdue').importance, Importance.max);
    expect(channelFor('dueSoon').importance, Importance.high);
    // Unknown ids fall back to the info channel.
    expect(channelFor('nope').id, 'info');
  });
}
