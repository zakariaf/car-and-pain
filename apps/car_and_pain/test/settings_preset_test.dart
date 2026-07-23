import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

/// M9-T2/T7: applying a regional preset sets every i18n axis at once (locale,
/// calendar, numeral, units, currency, week/fiscal boundaries) — a starting
/// point each axis can still override. Only display settings; no canonical data.
void main() {
  late AppDatabase db;
  late LocalizationController controller;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase.memory();
    settings = SettingsRepository(db);
    controller = LocalizationController(settings);
  });
  tearDown(() => db.close());

  test('the US preset sets imperial units, USD, gregorian, Sunday', () async {
    await controller.applyRegionalPreset(RegionalPreset.unitedStates);
    expect(await settings.get(SettingsKeys.locale), 'en');
    expect(await settings.get(SettingsKeys.calendar), 'gregorian');
    expect(await settings.get(SettingsKeys.numeral), 'western');
    expect(await settings.get(SettingsKeys.homeCurrency), 'USD');
    expect(await settings.get(SettingsKeys.distanceUnit), 'mile');
    expect(await settings.get(SettingsKeys.volumeUnit), 'usGallon');
    expect(await settings.get(SettingsKeys.temperatureUnit), 'fahrenheit');
    expect(await settings.get(SettingsKeys.firstDayOfWeek), '7');
    expect(await settings.get(SettingsKeys.fiscalYearStart), '1-1');
  });

  test('the Iran preset sets Jalali/Persian/IRR with a Nowruz fiscal start',
      () async {
    await controller.applyRegionalPreset(RegionalPreset.iran);
    expect(await settings.get(SettingsKeys.calendar), 'jalali');
    expect(await settings.get(SettingsKeys.numeral), 'persian');
    expect(await settings.get(SettingsKeys.homeCurrency), 'IRR');
    expect(await settings.get(SettingsKeys.fiscalYearStart), '3-21');
  });

  test('a single axis still overrides the preset afterwards', () async {
    await controller.applyRegionalPreset(RegionalPreset.unitedStates);
    // Override just the calendar; the rest of the preset stands.
    await controller.setCalendar(CalendarSystem.jalali);
    expect(await settings.get(SettingsKeys.calendar), 'jalali');
    expect(await settings.get(SettingsKeys.homeCurrency), 'USD'); // unchanged
  });
}
