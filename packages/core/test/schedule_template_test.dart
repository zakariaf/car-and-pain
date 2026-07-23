import 'dart:convert';

import 'package:core/core.dart';
import 'package:test/test.dart';

/// M4-T3 — the pure schedule-template model + apply. Severe-duty layers shortened
/// overrides over the generic schedule without mutating it; apply anchors to the
/// vehicle's current odometer + date.
void main() {
  ScheduleTemplate template() => ScheduleTemplate.fromJson({
        'version': 1,
        'id': 'generic',
        'name': 'schedule.generic',
        'entries': [
          {
            'serviceType': 'oil_change',
            'logic': 'whicheverFirst',
            'distanceKm': 15000,
            'months': 12,
            'severeDistanceKm': 7500,
            'severeMonths': 6,
          },
          {
            'serviceType': 'spark_plugs',
            'logic': 'distance',
            'distanceKm': 60000
          },
          {'serviceType': 'brake_fluid', 'logic': 'time', 'months': 24},
        ],
      });

  Instant at(int y, int m, int d) =>
      Instant.fromDateTime(DateTime.utc(y, m, d));

  test('km fields parse to canonical metres', () {
    final oil = template().entries.first;
    expect(oil.distanceMetres, 15000000); // 15_000 km
    expect(oil.severeDistanceMetres, 7500000);
    expect(oil.months, 12);
    expect(oil.logic, ServiceIntervalLogic.whicheverFirst);
  });

  test('JSON round-trips structurally (community import/export ready)', () {
    final t = template();
    final reparsed = ScheduleTemplate.fromJson(
      jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>,
    );
    expect(reparsed.version, t.version);
    expect(reparsed.id, t.id);
    expect(reparsed.entries.length, t.entries.length);
    expect(reparsed.entries.first.severeDistanceMetres, 7500000);
    expect(reparsed.entries[2].months, 24);
  });

  group('apply anchors to current odometer + date', () {
    test('generic profile uses the generic intervals', () {
      final items = applyScheduleTemplate(
        template(),
        profile: ScheduleProfile.generic,
        anchorOdometerMetres: 100000000, // 100_000 km
        anchorDate: at(2026, 1, 1),
      );
      final oil = items.firstWhere((i) => i.serviceType == 'oil_change');
      expect(oil.nextDueOdometerMetres, 115000000); // +15_000 km
      expect(oil.nextDueDate, at(2027, 1, 1)); // +12 months
      expect(oil.intervalMonths, 12);

      final plugs = items.firstWhere((i) => i.serviceType == 'spark_plugs');
      expect(plugs.nextDueOdometerMetres, 160000000);
      expect(plugs.nextDueDate, isNull); // distance-only

      final fluid = items.firstWhere((i) => i.serviceType == 'brake_fluid');
      expect(fluid.nextDueOdometerMetres, isNull); // time-only
      expect(fluid.nextDueDate, at(2028, 1, 1)); // +24 months
    });

    test('severe-duty layers shortened overrides without mutating the template',
        () {
      final t = template();
      final items = applyScheduleTemplate(
        t,
        profile: ScheduleProfile.severeDuty,
        anchorOdometerMetres: 100000000,
        anchorDate: at(2026, 1, 1),
      );
      final oil = items.firstWhere((i) => i.serviceType == 'oil_change');
      expect(oil.nextDueOdometerMetres, 107500000); // +7_500 km (severe)
      expect(oil.nextDueDate, at(2026, 7, 1)); // +6 months (severe)

      // Entries with no severe override fall back to the generic value.
      final fluid = items.firstWhere((i) => i.serviceType == 'brake_fluid');
      expect(fluid.nextDueDate, at(2028, 1, 1)); // generic 24 months

      // The template itself is unchanged (severe values are still overrides).
      expect(t.entries.first.distanceMetres, 15000000);
      expect(t.entries.first.severeDistanceMetres, 7500000);
    });
  });
}
