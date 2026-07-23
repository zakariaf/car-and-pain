import '../time/temporal.dart';
import 'schedule_rule.dart';

/// One concrete OS notification to fire at an absolute [when] (F5). The
/// scheduler resolves recurrences/projections and localizes the copy *before*
/// building this, so the gateway does no time or text math — it just arms the
/// resolved strings. A deterministic [id] keeps reconcile idempotent across
/// reboots.
final class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.channelId = 'info',
    this.groupKey,
    this.payload,
  });

  final int id;
  final Instant when;

  /// Already-localized copy (built through the F4 i18n layer; never a raw key).
  final String title;
  final String body;

  /// Severity channel: `overdue` | `dueSoon` | `documents` | `info`.
  final String channelId;

  /// Digest grouping key; entries sharing a key collapse into one summary.
  final String? groupKey;

  /// The deep-link target armed with the OS notification (M1-T6): the router
  /// location to open when the user taps it (e.g. a reminder detail, or the
  /// Pit-lane for a digest). Opaque to the gateway; validated at the edge by the
  /// app's `mapNotificationPayload` before it drives navigation. Never contains
  /// personal data — only stable ids already in the URL.
  final String? payload;
}

/// A reminder's scheduling definition, mapped from the DB by the data layer so
/// the app never touches Drift (F5-T2). Carries the identity/copy fields plus
/// the pure [ScheduleRule] the engine evaluates.
final class ReminderScheduleDef {
  const ReminderScheduleDef({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.severity,
    required this.rule,
  });

  final String id;
  final String vehicleId;
  final String title;

  /// Severity/channel id.
  final String severity;
  final ScheduleRule rule;
}
