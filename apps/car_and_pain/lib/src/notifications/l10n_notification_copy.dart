import 'package:core/core.dart';
import 'package:l10n/l10n.dart';

import '../settings/locale_controller.dart';
import 'reminder_scheduler.dart';

/// The production [NotificationCopy] (F5-T5): builds every notification body
/// through the F4 i18n layer — ICU-plural-correct digest titles, the vehicle
/// name bidi-isolated so a Latin plate/VIN stays intact inside RTL, the due date
/// in the active calendar, and numbers in the active numeral system. No
/// hardcoded strings.
final class L10nNotificationCopy implements NotificationCopy {
  const L10nNotificationCopy({
    required this.l10n,
    required this.prefs,
    required this.utcOffsetMinutes,
  });

  final AppLocalizations l10n;
  final LocalizationPrefs prefs;
  final int utcOffsetMinutes;

  @override
  ({String body, String title}) forReminder(
    String vehicleName,
    ReminderScheduleDef def,
    NextDue due,
  ) {
    final dateLine = due.confidence == DueConfidence.exact
        ? l10n.notifDueOn(_date(due.dueAt))
        : l10n.notifDueEstimated(_date(due.dueAt));
    // First-strong isolate: a Latin name/plate stays LTR, a local-script name
    // keeps its own direction, both intact inside the (possibly RTL) body.
    return (title: def.title, body: '${isolate(vehicleName)} • $dateLine');
  }

  @override
  ({String body, String title}) forDigest(
    List<(String, ReminderScheduleDef)> group,
  ) =>
      (
        title: l10n.notifDigest(group.length),
        body: group.map((e) => e.$2.title).join(' • '),
      );

  String _date(Instant at) {
    final date = CalendarDate.fromInstant(
      at,
      prefs.calendar,
      utcOffsetMinutes: utcOffsetMinutes,
    );
    final fmt = resolveNumeralFormat(
      prefs.languageCode,
      system: prefs.numeralSystem,
    );
    final month =
        monthName(prefs.calendar, date.year, date.month, native: prefs.isRtl);
    return '${fmt.formatInt(date.day)} $month ${fmt.formatInt(date.year)}';
  }
}
