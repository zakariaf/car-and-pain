import 'package:data/data.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';
import 'package:notifications/notifications.dart';

import '../settings/locale_controller.dart';
import 'l10n_notification_copy.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'reminder_scheduler.dart';

/// The notification façade — created and initialized once at bootstrap (prod),
/// where it's overridden with the real instance. Reading it before the override
/// is a clear, immediate error rather than a silent no-op.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'override notificationServiceProvider in bootstrap()',
  ),
);

/// The shared permission surface (F5-T6), used by onboarding + reminder creation.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

/// Deep-link payloads from notifications tapped while the app is alive (M1-T6).
/// A listener maps each to a route via `mapNotificationPayload` and navigates.
final notificationTapProvider = StreamProvider<String?>(
  (ref) => ref.watch(notificationServiceProvider).taps,
);

/// The pure [NotificationGateway] the scheduler/reconciler talk to — the real
/// FLN-backed gateway in prod, a [FakeNotificationGateway] in tests.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => ref.watch(notificationServiceProvider).gateway,
);

/// The assembled [ReminderScheduler] for the active locale/prefs (F5-T5).
/// Rebuilds when the localization preferences change, so the next reconcile
/// re-arms with fresh strings, calendar and numerals.
final reminderSchedulerProvider =
    FutureProvider<ReminderScheduler>((ref) async {
  final prefs = ref.watch(localizationPrefsProvider);
  final l10n = await AppLocalizations.delegate.load(Locale(prefs.languageCode));
  final offset = DateTime.now().timeZoneOffset.inMinutes;
  return ReminderScheduler(
    schedules: ref.watch(notificationScheduleRepositoryProvider),
    ledger: ref.watch(ledgerRepositoryProvider),
    vehicles: ref.watch(vehiclesRepositoryProvider),
    gateway: ref.watch(notificationGatewayProvider),
    copy: L10nNotificationCopy(
      l10n: l10n,
      prefs: prefs,
      utcOffsetMinutes: offset,
    ),
    utcOffsetMinutes: offset,
  );
});
