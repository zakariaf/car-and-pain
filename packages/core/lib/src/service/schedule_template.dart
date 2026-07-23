/// M4-T3 · bundled maintenance-schedule templates. The pure, offline model +
/// parser (versioned JSON, community-import-ready) and the apply operation that
/// anchors a template to a vehicle's current odometer + date, layering the
/// severe-duty overrides on top of the generic schedule without mutating it.
library;

import '../scheduling/schedule_rule.dart';
import '../time/temporal.dart';
import 'service_schedule.dart';

/// Which maintenance profile to apply. Severe-duty layers shortened intervals
/// over the generic schedule (short trips, dust, towing, extreme climate).
enum ScheduleProfile { generic, severeDuty }

/// One template entry: a service type mapped to a default interval (distance in
/// canonical metres, time in whole months) plus optional severe-duty overrides.
/// Either dimension may be null so an entry can be purely one kind; [logic] picks
/// the governing rule. Distances are authored in whole kilometres in the JSON and
/// stored canonically here (a maintenance interval is always a round km value, so
/// the km↔metres round-trip is lossless).
final class ScheduleTemplateEntry {
  const ScheduleTemplateEntry({
    required this.serviceType,
    required this.logic,
    this.distanceMetres,
    this.months,
    this.severeDistanceMetres,
    this.severeMonths,
  });

  factory ScheduleTemplateEntry.fromJson(Map<String, dynamic> json) =>
      ScheduleTemplateEntry(
        serviceType: json['serviceType'] as String,
        logic: ServiceIntervalLogic.values.byName(json['logic'] as String),
        distanceMetres: _kmToMetres(json['distanceKm']),
        months: (json['months'] as num?)?.toInt(),
        severeDistanceMetres: _kmToMetres(json['severeDistanceKm']),
        severeMonths: (json['severeMonths'] as num?)?.toInt(),
      );

  final String serviceType;
  final ServiceIntervalLogic logic;
  final int? distanceMetres;
  final int? months;
  final int? severeDistanceMetres;
  final int? severeMonths;

  /// The distance interval for [profile] (severe override where present).
  int? distanceFor(ScheduleProfile profile) =>
      profile == ScheduleProfile.severeDuty
          ? (severeDistanceMetres ?? distanceMetres)
          : distanceMetres;

  /// The time interval (months) for [profile] (severe override where present).
  int? monthsFor(ScheduleProfile profile) =>
      profile == ScheduleProfile.severeDuty ? (severeMonths ?? months) : months;

  Map<String, dynamic> toJson() => {
        'serviceType': serviceType,
        'logic': logic.name,
        if (distanceMetres != null) 'distanceKm': distanceMetres! ~/ 1000,
        if (months != null) 'months': months,
        if (severeDistanceMetres != null)
          'severeDistanceKm': severeDistanceMetres! ~/ 1000,
        if (severeMonths != null) 'severeMonths': severeMonths,
      };

  static int? _kmToMetres(Object? km) =>
      km == null ? null : (km as num).toInt() * 1000;
}

/// A bundled, editable maintenance-schedule template. Honestly labelled
/// "generic": every applied interval stays user-overridable per vehicle.
final class ScheduleTemplate {
  const ScheduleTemplate({
    required this.version,
    required this.id,
    required this.name,
    required this.entries,
  });

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) =>
      ScheduleTemplate(
        version: (json['version'] as num).toInt(),
        id: json['id'] as String,
        name: json['name'] as String,
        entries: [
          for (final e in json['entries'] as List)
            ScheduleTemplateEntry.fromJson(e as Map<String, dynamic>),
        ],
      );

  /// The current template schema version — a newer file is refused by the
  /// loader that checks [version] against this.
  static const int currentVersion = 1;

  final int version;

  /// Stable template id (e.g. `generic`), for identifying an applied schedule.
  final String id;

  /// A localization key for the template's display name (never a raw string).
  final String name;
  final List<ScheduleTemplateEntry> entries;

  Map<String, dynamic> toJson() => {
        'version': version,
        'id': id,
        'name': name,
        'entries': [for (final e in entries) e.toJson()],
      };
}

/// One entry of an applied schedule — the initial next-due state anchored to the
/// vehicle's current odometer + date. Canonical (metres / UTC instant).
final class AppliedScheduleItem {
  const AppliedScheduleItem({
    required this.serviceType,
    required this.logic,
    this.nextDueOdometerMetres,
    this.nextDueDate,
    this.intervalDistanceMetres,
    this.intervalMonths,
  });

  final String serviceType;
  final ServiceIntervalLogic logic;
  final int? nextDueOdometerMetres;
  final Instant? nextDueDate;

  /// The resolved (profile-adjusted) interval, carried so a persisted reminder
  /// can re-anchor on completion. Null when that dimension is absent.
  final int? intervalDistanceMetres;
  final int? intervalMonths;
}

/// Apply [template] to a vehicle anchored at [anchorOdometerMetres] +
/// [anchorDate] under [profile] (M4-T3). Produces the initial next-due state:
/// `nextDueOdometer = anchor + interval.distance` and
/// `nextDueDate = anchor + interval.months` (calendar-correct). Severe-duty
/// layers shortened overrides over the generic entry **without mutating** the
/// template. Every produced interval remains overridable per vehicle.
List<AppliedScheduleItem> applyScheduleTemplate(
  ScheduleTemplate template, {
  required ScheduleProfile profile,
  required int anchorOdometerMetres,
  required Instant anchorDate,
}) {
  final out = <AppliedScheduleItem>[];
  for (final e in template.entries) {
    final distance = e.distanceFor(profile);
    final months = e.monthsFor(profile);
    out.add(
      AppliedScheduleItem(
        serviceType: e.serviceType,
        logic: e.logic,
        nextDueOdometerMetres:
            distance == null ? null : anchorOdometerMetres + distance,
        nextDueDate: months == null
            ? null
            : Recurrence(months, RecurrenceUnit.months).nextAfter(anchorDate),
        intervalDistanceMetres: distance,
        intervalMonths: months,
      ),
    );
  }
  return out;
}
