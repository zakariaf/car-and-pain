import 'package:car_and_pain/src/routing/notification_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// `mapNotificationPayload` is the untrusted-input edge for notification taps
/// (M1-T6): it must pass Room roots and Garage content details through, and
/// reject everything else — gate flows, Settings, Trash, and malformed paths —
/// to `null` (open normally, no deep link).
void main() {
  group('mapNotificationPayload accepts', () {
    const valid = {
      '/cockpit': '/cockpit',
      '/garage': '/garage',
      '/pitlane': '/pitlane',
      '/garage/v1': '/garage/v1',
      '/garage/veh-42/reminders/rem-7': '/garage/veh-42/reminders/rem-7',
      // Surrounding whitespace is trimmed before matching.
      '  /pitlane  ': '/pitlane',
    };
    for (final entry in valid.entries) {
      test('"${entry.key}" → "${entry.value}"', () {
        expect(mapNotificationPayload(entry.key), entry.value);
      });
    }
  });

  group('mapNotificationPayload rejects', () {
    const rejected = <String?>[
      null,
      '',
      '   ',
      // Gate flows must never be a deep-link target.
      '/lock',
      '/splash',
      '/onboarding',
      '/startup-error',
      // Destructive / settings flows.
      '/trash',
      '/gallery',
      '/settings',
      '/settings/backup',
      // Wrong shapes under /garage.
      '/garage/',
      '/garage/v1/reminders',
      '/garage/v1/reminders/',
      '/garage/v1/service/s1',
      '/garage/v1/reminders/r1/extra',
      // Not a known root, not garage.
      '/fuel/f1',
      'garage/v1', // no leading slash
      'https://evil.example/garage/v1',
    ];
    for (final input in rejected) {
      test('${input ?? '<null>'} → null', () {
        expect(mapNotificationPayload(input), isNull);
      });
    }
  });
}
